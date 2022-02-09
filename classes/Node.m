classdef Node < handle
    %NODE class
    %   Represents a single network node in a network
    properties ( Access = private )
        localtime = 0;
        inited = 0;
        connected = 0;   
        debug = 1;             % show debug text
        msg
    end
    properties
        id
        color 
        radius
        x
        y
        energy
        loss
        uptime        
        packets
        bytes
        queue
        waypoint
        rxlisn
        txlisn
        lklisn
        curproto
        phy
        link
        % 1. 在此处添加自定义协议
        neighbor
        hlmrp
        odmrp
        
        % 2. 
        Neighbors %每个结点都维护一个1跳邻居列表，包括邻居的id和坐标，刘
        isCritical = -1 %标识当前节点是否是关键节点，非关键节点代表种子节点,0：非关键节点，1：关键节点，-1：初始值
        gradient = Inf %标识当前时刻的梯度值
        %dist = Inf %标识当前节点到最近非关键节点的距离，若本身是非关键节点则为0.初始设置为Inf
        backup = -1 %标识当前节点最终选择的备份节点，只有关键节点才需要备份节点
        curBackup = -1 %表示当前时刻节点选择的备份节点
        %preBackup = -1 %表示上个时刻节点选择的备份节点
        monitor = [] %标识当前节点所监视的邻居节点
        stable = 0 %标识当前节点的梯度是否已经平稳，0表示不平稳，1表示平稳
        
        % 3. haveHeart信息表示结点是否发生故障，刘
        haveHeart
        

    end
    
    events %定义事件
        PacketStart % emitted when packet sending started on tx node 
        PacketSent  % emitted when packet is sent on tx node 
    end
    
    methods
      function obj = Node(id, x, y, simtime, speed, uptime, loss, energy, phy, mac, protocols, agent, apps,nodeCount)
            obj.id = id;
            obj.color = [0.67 1 0.18]; % gray by default
            obj.radius = 180; 
            obj.x = x;
            obj.y = y;
            obj.loss = loss; % loss percent [0...1] 损失百分比
            %obj.waypoint = Waypoint(simtime, speed);
            %使用自定义移动模型,刘
            obj.waypoint = MissionModel(speed);
            obj.queue = Queue(100); % tx queue 发送消息队列
            obj.packets = struct('sent',0,'rcvd',0,'dropped',0,'relayed',0);
            obj.bytes = struct('sent',0,'rcvd',0,'dropped',0,'relayed',0);
            obj.energy = energy;
            obj.uptime = uptime; 
            obj.phy = phy;
            obj.link = LinkModel(id,mac.proto,mac.enabled);
            %监听链路的finishedSending事件，触发回调函数
            obj.lklisn = addlistener(obj.link,'finishedSending',@obj.sent_pkt); 
            % 2. 这里初始化协议
            p = size(protocols);
            for i=1:p(2)                
                switch upper(char(protocols(i)))
                    case 'NEIGHBOR'
                        obj.neighbor = Neighbor(id); 
                    case 'HLMRP'
                        obj.hlmrp = HLMRP(id, agent, apps);
                    case 'ODMRP'
                        obj.odmrp = ODMRP(id, agent, apps);
                    otherwise
                        error('unknown protocol');
                end
            end
            obj.haveHeart = 1;
      end
      
      % 此函数确定是否应生成新数据包，每次暂停模拟时调用
      % 数据包可以通过超时生成，也可以从发送队列中提取
      function [type, p] = generate_pkt(obj, t, delay, p)
          
          type = '';
          obj.localtime = t;
          if obj.uptime > t              
              return
          elseif obj.inited==0
              %obj.color = [33 205 163] ./ 255;
              obj.inited = 1;
          else 
              %先注释掉,刘
              %obj.waypoint.timeout;
              obj.link.timeout(delay);
              % 着色节点
%                if isempty(obj.neighbor) == 0
%                    obj.color = [1 1 0];
%                elseif isempty(obj.odmrp) == 0
%                    obj.color = [1 1 0];
%                end
          end
          
          % 协议超时 生成pkt----------------------------------------
          % Neighbor protocol timeout function
          if isempty(obj.neighbor) == 0 
              [obj.neighbor, pkt] = obj.neighbor.timeout(delay, t);
              if obj.neighbor.result > 0 % 超时时生成的数据包
                  obj.send_pkt(pkt);
              end
          end
                   
          % HLMRP protocol timeout function
          if isempty(obj.hlmrp) == 0
              [obj.hlmrp, pkt] = obj.hlmrp.timeout(delay, t);              
              
              if obj.hlmrp.result > 0 % packet generated on timeout              
                  obj.send_pkt(pkt);
              end
          end
          
          % ODMRP protocol timeout function
          if isempty(obj.odmrp) == 0
              [obj.odmrp, pkt] = obj.odmrp.timeout(delay, t);
              
              
              if obj.odmrp.result > 0 % packet generated on timeout              
                  obj.send_pkt(pkt);
              end    
          end
          
          
          % Process outgoing queue 处理传出队列
          if obj.queue.NumElements > 0 && obj.link.until <= 0 % 防止同时发送多个数据包，因此只需等待数据包被传输       
              pkt = obj.queue.remove();   % fetch IPv6 packet from TX queue         
              obj.link.lastlen = pkt.len; % 将此数据包的长度放入链路层
              type = pkt.getType;         % get the packet type      
              p = p + 1;                  % global increment of packets TX
              
              if obj.link.checkLinkBusy(t) == 1
                  return;
              end
              
              %传数据包
              obj.link.linkLockTx(obj.id, obj.phy.duration(pkt.len), pkt); % enable MAC protocol
              notify(obj,'PacketStart');   % 立即开始发送数据包
                  
              obj.packets.sent = obj.packets.sent + 1; 
              obj.bytes.sent = obj.bytes.sent + pkt.len;
                             
          end       
      end
      
      function send_pkt(obj, pkt)
          %往pkt中加入发送者的坐标和发送者的梯度值,刘
          %disp("发送者"+obj.id+" x="+obj.x+" y="+obj.y);
          pkt.x = obj.x;
          pkt.y = obj.y;
          pkt.srcId = obj.id;
          pkt.gradient = obj.gradient;
          pkt.backup = obj.backup;
          %
          obj.queue.add(pkt); % 我们将传出数据包放入tx队列
      end

      %接收pkt
      function rcvd_pkt(obj,src,~)   
          
          pkt = src.link.pkt; % 从发送节点的链路层提取pkt，就像成功接收一样：）               
          
          obj.link.linkReleaseRx; % 至少有一个节点已完成发送            
          %fprintf('medium at Node %d, busy=%d, err=%d\r',obj.id, obj.link.busy, obj.link.err);
          
          if obj.link.isBusy == 0 % 若媒体空闲，我们可以接收数据包             
              %接收邻居信息,刘
              obj.Neighbors(pkt.srcId,1) = pkt.x;
              obj.Neighbors(pkt.srcId,2) = pkt.y;
              obj.Neighbors(pkt.srcId,3) = pkt.gradient;
              fprintf('%d send hello to %d\r\n',pkt.srcId,obj.id);  
              %使用梯度扩散机制来更新梯度
              
              %若当前节点是关键节点，则计算与邻居节点的距离
              if obj.isCritical == 1
                  dist = [];
                  for i=1:size(obj.Neighbors,1)
                      x1 = obj.Neighbors(i,1);
                      y1 = obj.Neighbors(i,2);
                      if x1 == 0 && y1==0
                          dist = [dist;Inf];
                          continue;
                      end
                      x2 = obj.x;
                      y2 = obj.y;
                      range=sqrt((x2-x1)^2+(y2-y1)^2);
                      dist = [dist;range];
                  end

                  %选择当前时刻的备份节点
                  tmp = Inf;
                  for i=1:size(dist,1)
                      if (obj.Neighbors(i,3)+dist(i,1))<tmp
                          tmp = obj.Neighbors(i,3)+dist(i,1);
                          obj.curBackup = i;
                      end
                  end

                  preGradient = obj.gradient;
                  obj.gradient =  min(obj.gradient,min(obj.Neighbors(:,3)+dist));

                  if preGradient == obj.gradient %如何本时刻的梯度与上时刻的梯度一样，则已收敛
                      obj.backup = obj.curBackup;
                      obj.stable = 1;
                  else
                      obj.stable = 0;
                  end
              else
                  obj.stable = 1;  
              end
              
              %fprintf('rcvd_pkt, %d from %d, pkt.next: %s，src.x: %d,src.y:%d\r\n', obj.id, src.id, pkt.next,pkt.x,pkt.y);    
              %              
              % 更新统计数据
              obj.packets.rcvd = obj.packets.rcvd + 1;
              obj.bytes.rcvd = obj.bytes.rcvd + pkt.len;
              
              if ~isempty(pkt.next)
                  switch pkt.next
                      case 'NEIGHBOR'
                          [obj.neighbor, pkt] = obj.neighbor.process_data(pkt);               
                          if obj.neighbor.result > 0
                              obj.send_pkt(pkt);
                          elseif obj.neighbor.result < 0
                              obj.packets.dropped = obj.packets.dropped + 1;
                              obj.bytes.dropped = obj.bytes.dropped + pkt.len;
                          end
                      case 'HLMRP'
                          % HLMRP process packet if not NODE
                          if obj.neighbor.cluster ~= Cluster.NODE
                              [obj.hlmrp, pkt] = obj.hlmrp.process_data(pkt);   
                              if obj.hlmrp.result > 0
                                  obj.send_pkt(pkt);
                              elseif obj.hlmrp.result < 0
                                  obj.packets.dropped = obj.packets.dropped + 1;
                                  obj.bytes.dropped = obj.bytes.dropped + pkt.len;
                              end       
                          end
                      case 'ODMRP'
                          % ODMRP process packet                       
                          [obj.odmrp, pkt] = obj.odmrp.process_data(pkt);   
                          if obj.odmrp.result > 0
                              obj.send_pkt(pkt);
                          elseif obj.odmrp.result < 0
                              obj.packets.dropped = obj.packets.dropped + 1;
                              obj.bytes.dropped = obj.bytes.dropped + pkt.len;
                          end       

                      %
                      % Add custom protocol process function
                      %                  
                      otherwise
                  end
              end
              
          end
      end
      
      function start_pkt(obj,src,~)
          %fprintf('start_pkt, %d -> %d\r\n', src.id, obj.id);
          obj.link.linkLockRx(src.id);
      end
      
      function sent_pkt(obj,~,~)
          %fprintf('sent_pkt, %d\r\n', obj.id);
          obj.link.linkReleaseTx;
          %定义触发数据包发送事件
          notify(obj,'PacketSent'); 
          
          %先注释掉，刘
          %fprintf(obj.msg); % print out log to command window
      end
            
      function obj = connectListener(obj,src) 
          if obj.inited == 0
              return
          end
          if obj.connected == 0
            obj.rxlisn = addlistener(src,'PacketSent',@(s,evnt)obj.rcvd_pkt(s,evnt));
            obj.txlisn = addlistener(src,'PacketStart',@obj.start_pkt);                              
            obj.connected = 1;
          end
      end
      
      function obj = enableListener(obj)
          if obj.inited == 0
              return
          end
          if obj.connected == 1
            obj.rxlisn.Enabled = true;
            obj.txlisn.Enabled = true;
          end
      end
      
      function obj = disableListener(obj)
          if obj.inited == 0
              return
          end          
          if obj.connected == 1
            obj.rxlisn.Enabled = false;
            obj.txlisn.Enabled = false;
          end
      end
      
      function obj = deleteListener(obj)
          if obj.inited == 0
              return
          end          
          if obj.connected == 1
            delete(obj.rxlisn);
            delete(obj.txlisn);
            obj.connected = 0;
          end
      end
      
      function setColor(obj,color)
          obj.color = color;
      end
      
      function setUptime(obj,up)          
         if (isnumeric(up))
            obj.uptime = up;
         else
            error('Invalid uptime');
         end
      end  
      
      function setEnergy(obj,e)          
         if (isnumeric(e))
            obj.energy = e;
         else
            error('Invalid energy');
         end
      end      
      
      function setCoord(obj,x,y)          
         if (isnumeric(x) && isnumeric(y))
             obj.x = x;
             obj.y = y;             
         else
            error('Invalid coordinates');
         end
      end
      
      function setX(obj,x)
          if (isnumeric(x))
            obj.x = x;
          else
            error('Invalid coordinate');
          end
      end
      
      function setY(obj,y)
          if (isnumeric(y))
            obj.y = y;
          else
            error('Invalid coordinate');
          end
      end
      
      % 补充，刘
      function setHaveHeart(obj,haveHeart)
          if (isnumeric(haveHeart))
            obj.haveHeart = haveHeart;
          else
            error('Invalid haveHeart');
          end
      end
      %
    end
    
end

