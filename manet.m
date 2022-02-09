warning on
warning off verbose
warning off backtrace

clear Nodes;

%% 读取配置文件 ---------------------------------------------
ini = ini2struct('config.ini');

%% runtime vars -----------------------------------------------
P = 0;                                                          % total packets generated in the simulation
UP = ini.globals.SIMTIME / 100;                                 % 节点的苏醒时间，仿真时间/100
L = randi([0 ini.globals.LOSS],1,ini.constants.NODES);          % node loss matrix
U = randi([0 UP],1,ini.constants.NODES);                        % 节点开始时间矩阵
E = randi([0 100],1,ini.constants.NODES);                       % node energy matrix
if ini.topology.retain == 0
    %这里设置节点初始坐标
    %Coord = randi([0 ini.globals.SQUARE], ini.constants.NODES, 2);  % 节点初始坐标矩阵NODES*2,0-2000的随机值
    
    %自定义节点初始坐标，刘
    Coord = [350 170;180 250;253 140;233 210;200 60;286 50;20 110;447 130;54 180;110 100];
    %Coord = [10 150;150 150;10 10;150 10];
    %Coord = [163 233;211 275;287 235;133 88;25 45;17 255;189 236;239 81;208 68;103 96;284 249;156 247;287 171;22 172;62 86];
    %Coord = [0 1000;200 1000;200 1200;200 800;400 1000;600 1000;600 1200;600 800;800 1000;1000 1000];
    %Coord = [100 100;100 500;300 300;500 100;500 500;700 300;700 700;900 900];
% TODO: 为节点添加拓扑生成器和代理角色
% else
%     Coord = ini.topology.coord;
end

%% PHY used in this simulation --------------------------------
PHY = PhyModel(ini.globals.RADIO, ini.phy);

%% MAC protocol used in this simulation -----------------------
MAC = macmodel(ini.constants.NODES, ini.mac); % 将来每个节点都将有自己的MAC协议

%% Protocols used in this simulation --------------------------
Protocols = getproto(ini.routing.proto);

%% Agents used in this simulation -----------------------------
if ini.agents.retain == 0
    Agents = agentrole(ini.constants.NODES, ini.constants.SENDERS, ini.constants.RECEIVERS);  % 0 - no data traffic, 1 - receiver, 2 - sender
else
    Agents = ini.agents;
end
%% Applications used in this simulation -----------------------
Apps = ini.apps;

%% init nodes -------------------------------------------------
for i=1:ini.constants.NODES
    Nodes(i) = Node(i,Coord(i,1),Coord(i,2),ini.globals.SIMTIME,ini.globals.SPEED,U(i),L(i),E(i),PHY,MAC(i),Protocols,Agents(i),Apps,ini.constants.NODES);
end


% 记录故障节点，刘
faultNode = -1; %记录当前故障节点
fixNode = -1;
isStable = 0;%表示梯度分布是否已稳定
restoreComplete = 0;
faultList = []; %记录所有故障的节点

% 实验结果
totalDist = 0;

% update topology matrix 拓扑矩阵(邻接矩阵)
A = topology(Coord, Nodes,faultList); 
for i=1:ini.constants.NODES
    Nodes(i).Neighbors = addNeighbors(A,Coord,i);
    Nodes(i).isCritical = isCritical(Nodes(i).Neighbors,ini.globals.RADIO);
end
%% start discrete simulation ----------------------------------
for t = 1:ini.globals.SAMPLING:ini.globals.SIMTIME % 带有步长的for循环
    pause(ini.globals.DELAYPLOT/1000);  
        
    % 更新绘图 点
    A = topology(Coord, Nodes,faultList); 
    [a,c] = nodecolors(Nodes); 
    s = scatter(Coord(:,1),Coord(:,2),a,c,'filled');
 
    for j=1:ini.constants.NODES                      
        %判断是否故障节点,刘
        if Nodes(j).haveHeart == 0
            continue;
        end               
        % 画出节点序号和梯度值
        if Nodes(j).id<10
            text(Nodes(j).x-2,Nodes(j).y,num2str(Nodes(j).id,'%d'));
        else
            text(Nodes(j).x-5,Nodes(j).y,num2str(Nodes(j).id,'%d'));
        end
        if Nodes(j).gradient==Inf
            g = "Inf";
        else
            g = num2str(Nodes(j).gradient);
        end
        text(Nodes(j).x+10,Nodes(j).y-10,g);
        if Nodes(j).isCritical == 1
            text(Nodes(j).x+10,Nodes(j).y-20,num2str(Nodes(j).curBackup,'%d'));
        end


        % 首先，我们根据拓扑结构连接邻居节点的侦听器
        for k=1:ini.constants.NODES
            if A(j,k) == 1
                Nodes(k).connectListener(Nodes(j));                
            end
        end

        % 现在，处理新数据包的输出队列
        for k=1:ini.constants.NODES
            if k~=faultNode
                [message, P] = Nodes(j).generate_pkt(t,ini.globals.SAMPLING,P);
            end         
        end

        % loop thru neighbors 
        for k=1:ini.constants.NODES                   
            % delete connected listener and plot link 删除连接的侦听器和打印链接
            if A(j,k) == 1
                Nodes(k).deleteListener();
                if ini.visuals.showalledges == 1
                    line( [Nodes(j).x Nodes(k).x], [Nodes(j).y Nodes(k).y],'Color','r','LineStyle','-');              
                end 
            end

        end                      
    end
    
    if mod(t,100) == 0
        for j=1:ini.constants.NODES   
            if Nodes(j).haveHeart == 0
                continue
            end
            if Nodes(j).isCritical ==1
                Nodes(j).color = [1 0 0];
            else
                Nodes(j).color = [0.67 1 0.18];
                Nodes(j).gradient = 0; %将非关键节点设置为种子节点，梯度为0
            end      
        end
        if isStable == 1
        else
            distribution = zeros(ini.constants.NODES,1);
            for j=1:ini.constants.NODES
                distribution(j,1) = Nodes(j).stable;
            end
            if sum(distribution) == size(distribution,1)
                isStable = 1;
                for j=1:ini.constants.NODES
                    if Nodes(j).haveHeart == 0
                        continue;
                    end
                    if Nodes(j).backup ~= -1
                        Nodes(Nodes(j).backup).monitor = [Nodes(Nodes(j).backup).monitor j];
                    end
                end
            end
        end
        
    end
    if isStable == 1
        disp("梯度分布已稳定");
%         for j=1:ini.constants.NODES %选择一个关键节点作为故障节点
%             if Nodes(j).isCritical == 1 && Nodes(j).haveHeart == 1
%                 faultNode = j;
%                 faultList = [faultList faultNode];
%                 Nodes(faultNode).haveHeart = 0;
%                 Nodes(faultNode).radius = 1;
%                 totalDist = totalDist + Nodes(j).gradient;
%                 break;
%             end
%         end
        faultNode = input('请输入故障节点编号：');
        faultList = [faultList faultNode];
        Nodes(faultNode).haveHeart = 0;
        Nodes(faultNode).radius = 1;
        totalDist = totalDist + Nodes(j).gradient;
        if faultNode ~= -1
            for j=1:ini.constants.NODES
                if Nodes(j).haveHeart==0
                    continue
                end
                if ismember(faultNode,Nodes(j).monitor)
                    disp(j+"号节点监视发现："+faultNode+"号节点发生了故障！");
                    disp(j+"号节点将要替换故障节点！")
                    fixNode = j;
                    break;
                end
            end        
            %发生了故障要重置梯度
            for j=1:ini.constants.NODES
                if Nodes(j).haveHeart == 0
                    continue;
                end
                Nodes(j).stable = 0;
            end
        end   
        
        if faultNode ~= -1 && fixNode == -1 % 出现环的情况
            restoreComplete = 1;
            %发生了故障要重置梯度
            for j=1:ini.constants.NODES
                if Nodes(j).haveHeart == 0
                    continue;
                end
                Nodes(j).stable = 0;
            end
        end
        
        isStable = 0;
    end
    
    while fixNode ~= -1
        x1 = Nodes(fixNode).x;
        y1 = Nodes(fixNode).y;
        if ~ismember(faultNode,Nodes(fixNode).monitor)
            disp("error");
            break;
        end
        %x2 = Nodes(fixNode).Neighbors(Nodes(fixNode).monitor,1);
        %y2 = Nodes(fixNode).Neighbors(Nodes(fixNode).monitor,2);
        x2 = Nodes(fixNode).Neighbors(faultNode,1);
        y2 = Nodes(fixNode).Neighbors(faultNode,2);

        if abs(x1-x2)<=2 && abs(y1-y2)<2
            if Nodes(fixNode).isCritical == 1
                faultNode = fixNode;
                disp("关键节点"+fixNode+"通知它的备份节点自己将要重定位");
                fixNode = Nodes(fixNode).backup;
            else
                fixNode = -1;
                restoreComplete = 1;
                faultNode = -1;
            end
        else
            angle = Cangle(x1,y1,x2,y2);
            [Coord(fixNode,1),Coord(fixNode,2)]=mobility(x1,y1,(ini.globals.SPEED/250*ini.globals.SAMPLING),angle); 
            Nodes(fixNode).setCoord(Coord(fixNode,1),Coord(fixNode,2));
            A = topology(Coord, Nodes,faultList);         
        end
        % 更新绘图 点和边
        [a,c] = nodecolors(Nodes); 
        s = scatter(Coord(:,1),Coord(:,2),a,c,'filled');

        for j=1:ini.constants.NODES                      
            %判断是否故障节点,刘
            if Nodes(j).haveHeart == 0
                continue;
            end               
            % 画出节点序号和梯度值
            if Nodes(j).id<10
                text(Nodes(j).x-2,Nodes(j).y,num2str(Nodes(j).id,'%d'));
            else
                text(Nodes(j).x-5,Nodes(j).y,num2str(Nodes(j).id,'%d'));
            end
            % loop thru neighbors 
            for k=1:ini.constants.NODES            
                %测试，刘
                if Nodes(k).haveHeart ==0
                    continue;
                end
                %        
                % delete connected listener and plot link 删除连接的侦听器和打印链接
                if k~=j && A(j,k) == 1
                    Nodes(k).deleteListener();
                    if ini.visuals.showalledges == 1
                        line( [Nodes(j).x Nodes(k).x], [Nodes(j).y Nodes(k).y],'Color','r','LineStyle','-');              
                    end 
                end

            end

        end
        pause(ini.globals.DELAYPLOT/1000);  
        
    end
    
    % 更新矩阵
    A = topology(Coord, Nodes,faultList); 
    
    if restoreComplete == 1
        %disp("恢复过程结束！");
        %disp("------------------------------------------------");
        for i=1:ini.constants.NODES
            if Nodes(i).haveHeart == 0
                continue;
            end
            Nodes(i).Neighbors = addNeighbors(A,Coord,i);
            Nodes(i).isCritical = isCritical(Nodes(i).Neighbors,ini.globals.RADIO);
            if Nodes(i).isCritical == 1
                Nodes(i).gradient = Inf;
                Nodes(i).color = [1 0 0];
            else
                Nodes(i).color = [0.67 1 0.18];
                Nodes(i).gradient = 0; %将非关键节点设置为种子节点，梯度为0
            end
            Nodes(i).monitor = [];
            Nodes(i).backup = -1;

            restoreComplete = 0;
        end
    end
    
   
    
        
    
end

%% print statistics
if printstat == 1
    simstat(ini.globals.SIMTIME,Nodes,ini.globals.SENDERS,ini.globals.RECEIVERS,Protocols,Apps);
end

