warning on
warning off verbose
warning off backtrace

clear Nodes;

%% ��ȡ�����ļ� ---------------------------------------------
ini = ini2struct('config.ini');

%% runtime vars -----------------------------------------------
P = 0;                                                          % total packets generated in the simulation
UP = ini.globals.SIMTIME / 100;                                 % �ڵ������ʱ�䣬����ʱ��/100
L = randi([0 ini.globals.LOSS],1,ini.constants.NODES);          % node loss matrix
U = randi([0 UP],1,ini.constants.NODES);                        % �ڵ㿪ʼʱ�����
E = randi([0 100],1,ini.constants.NODES);                       % node energy matrix
if ini.topology.retain == 0
    %�������ýڵ��ʼ����
    %Coord = randi([0 ini.globals.SQUARE], ini.constants.NODES, 2);  % �ڵ��ʼ�������NODES*2,0-2000�����ֵ
    
    %�Զ���ڵ��ʼ���꣬��
    Coord = [350 170;180 250;253 140;233 210;200 60;286 50;20 110;447 130;54 180;110 100];
    %Coord = [10 150;150 150;10 10;150 10];
    %Coord = [163 233;211 275;287 235;133 88;25 45;17 255;189 236;239 81;208 68;103 96;284 249;156 247;287 171;22 172;62 86];
    %Coord = [0 1000;200 1000;200 1200;200 800;400 1000;600 1000;600 1200;600 800;800 1000;1000 1000];
    %Coord = [100 100;100 500;300 300;500 100;500 500;700 300;700 700;900 900];
% TODO: Ϊ�ڵ���������������ʹ����ɫ
% else
%     Coord = ini.topology.coord;
end

%% PHY used in this simulation --------------------------------
PHY = PhyModel(ini.globals.RADIO, ini.phy);

%% MAC protocol used in this simulation -----------------------
MAC = macmodel(ini.constants.NODES, ini.mac); % ����ÿ���ڵ㶼�����Լ���MACЭ��

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


% ��¼���Ͻڵ㣬��
faultNode = -1; %��¼��ǰ���Ͻڵ�
fixNode = -1;
isStable = 0;%��ʾ�ݶȷֲ��Ƿ����ȶ�
restoreComplete = 0;
faultList = []; %��¼���й��ϵĽڵ�

% ʵ����
totalDist = 0;

% update topology matrix ���˾���(�ڽӾ���)
A = topology(Coord, Nodes,faultList); 
for i=1:ini.constants.NODES
    Nodes(i).Neighbors = addNeighbors(A,Coord,i);
    Nodes(i).isCritical = isCritical(Nodes(i).Neighbors,ini.globals.RADIO);
end
%% start discrete simulation ----------------------------------
for t = 1:ini.globals.SAMPLING:ini.globals.SIMTIME % ���в�����forѭ��
    pause(ini.globals.DELAYPLOT/1000);  
        
    % ���»�ͼ ��
    A = topology(Coord, Nodes,faultList); 
    [a,c] = nodecolors(Nodes); 
    s = scatter(Coord(:,1),Coord(:,2),a,c,'filled');
 
    for j=1:ini.constants.NODES                      
        %�ж��Ƿ���Ͻڵ�,��
        if Nodes(j).haveHeart == 0
            continue;
        end               
        % �����ڵ���ź��ݶ�ֵ
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


        % ���ȣ����Ǹ������˽ṹ�����ھӽڵ��������
        for k=1:ini.constants.NODES
            if A(j,k) == 1
                Nodes(k).connectListener(Nodes(j));                
            end
        end

        % ���ڣ����������ݰ����������
        for k=1:ini.constants.NODES
            if k~=faultNode
                [message, P] = Nodes(j).generate_pkt(t,ini.globals.SAMPLING,P);
            end         
        end

        % loop thru neighbors 
        for k=1:ini.constants.NODES                   
            % delete connected listener and plot link ɾ�����ӵ��������ʹ�ӡ����
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
                Nodes(j).gradient = 0; %���ǹؼ��ڵ�����Ϊ���ӽڵ㣬�ݶ�Ϊ0
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
        disp("�ݶȷֲ����ȶ�");
%         for j=1:ini.constants.NODES %ѡ��һ���ؼ��ڵ���Ϊ���Ͻڵ�
%             if Nodes(j).isCritical == 1 && Nodes(j).haveHeart == 1
%                 faultNode = j;
%                 faultList = [faultList faultNode];
%                 Nodes(faultNode).haveHeart = 0;
%                 Nodes(faultNode).radius = 1;
%                 totalDist = totalDist + Nodes(j).gradient;
%                 break;
%             end
%         end
        faultNode = input('��������Ͻڵ��ţ�');
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
                    disp(j+"�Žڵ���ӷ��֣�"+faultNode+"�Žڵ㷢���˹��ϣ�");
                    disp(j+"�Žڵ㽫Ҫ�滻���Ͻڵ㣡")
                    fixNode = j;
                    break;
                end
            end        
            %�����˹���Ҫ�����ݶ�
            for j=1:ini.constants.NODES
                if Nodes(j).haveHeart == 0
                    continue;
                end
                Nodes(j).stable = 0;
            end
        end   
        
        if faultNode ~= -1 && fixNode == -1 % ���ֻ������
            restoreComplete = 1;
            %�����˹���Ҫ�����ݶ�
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
                disp("�ؼ��ڵ�"+fixNode+"֪ͨ���ı��ݽڵ��Լ���Ҫ�ض�λ");
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
        % ���»�ͼ ��ͱ�
        [a,c] = nodecolors(Nodes); 
        s = scatter(Coord(:,1),Coord(:,2),a,c,'filled');

        for j=1:ini.constants.NODES                      
            %�ж��Ƿ���Ͻڵ�,��
            if Nodes(j).haveHeart == 0
                continue;
            end               
            % �����ڵ���ź��ݶ�ֵ
            if Nodes(j).id<10
                text(Nodes(j).x-2,Nodes(j).y,num2str(Nodes(j).id,'%d'));
            else
                text(Nodes(j).x-5,Nodes(j).y,num2str(Nodes(j).id,'%d'));
            end
            % loop thru neighbors 
            for k=1:ini.constants.NODES            
                %���ԣ���
                if Nodes(k).haveHeart ==0
                    continue;
                end
                %        
                % delete connected listener and plot link ɾ�����ӵ��������ʹ�ӡ����
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
    
    % ���¾���
    A = topology(Coord, Nodes,faultList); 
    
    if restoreComplete == 1
        %disp("�ָ����̽�����");
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
                Nodes(i).gradient = 0; %���ǹؼ��ڵ�����Ϊ���ӽڵ㣬�ݶ�Ϊ0
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

