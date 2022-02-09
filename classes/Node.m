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
        % 1. �ڴ˴�����Զ���Э��
        neighbor
        hlmrp
        odmrp
        
        % 2. 
        Neighbors %ÿ����㶼ά��һ��1���ھ��б������ھӵ�id�����꣬��
        isCritical = -1 %��ʶ��ǰ�ڵ��Ƿ��ǹؼ��ڵ㣬�ǹؼ��ڵ�������ӽڵ�,0���ǹؼ��ڵ㣬1���ؼ��ڵ㣬-1����ʼֵ
        gradient = Inf %��ʶ��ǰʱ�̵��ݶ�ֵ
        %dist = Inf %��ʶ��ǰ�ڵ㵽����ǹؼ��ڵ�ľ��룬�������Ƿǹؼ��ڵ���Ϊ0.��ʼ����ΪInf
        backup = -1 %��ʶ��ǰ�ڵ�����ѡ��ı��ݽڵ㣬ֻ�йؼ��ڵ����Ҫ���ݽڵ�
        curBackup = -1 %��ʾ��ǰʱ�̽ڵ�ѡ��ı��ݽڵ�
        %preBackup = -1 %��ʾ�ϸ�ʱ�̽ڵ�ѡ��ı��ݽڵ�
        monitor = [] %��ʶ��ǰ�ڵ������ӵ��ھӽڵ�
        stable = 0 %��ʶ��ǰ�ڵ���ݶ��Ƿ��Ѿ�ƽ�ȣ�0��ʾ��ƽ�ȣ�1��ʾƽ��
        
        % 3. haveHeart��Ϣ��ʾ����Ƿ������ϣ���
        haveHeart
        

    end
    
    events %�����¼�
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
            obj.loss = loss; % loss percent [0...1] ��ʧ�ٷֱ�
            %obj.waypoint = Waypoint(simtime, speed);
            %ʹ���Զ����ƶ�ģ��,��
            obj.waypoint = MissionModel(speed);
            obj.queue = Queue(100); % tx queue ������Ϣ����
            obj.packets = struct('sent',0,'rcvd',0,'dropped',0,'relayed',0);
            obj.bytes = struct('sent',0,'rcvd',0,'dropped',0,'relayed',0);
            obj.energy = energy;
            obj.uptime = uptime; 
            obj.phy = phy;
            obj.link = LinkModel(id,mac.proto,mac.enabled);
            %������·��finishedSending�¼��������ص�����
            obj.lklisn = addlistener(obj.link,'finishedSending',@obj.sent_pkt); 
            % 2. �����ʼ��Э��
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
      
      % �˺���ȷ���Ƿ�Ӧ���������ݰ���ÿ����ͣģ��ʱ����
      % ���ݰ�����ͨ����ʱ���ɣ�Ҳ���Դӷ��Ͷ�������ȡ
      function [type, p] = generate_pkt(obj, t, delay, p)
          
          type = '';
          obj.localtime = t;
          if obj.uptime > t              
              return
          elseif obj.inited==0
              %obj.color = [33 205 163] ./ 255;
              obj.inited = 1;
          else 
              %��ע�͵�,��
              %obj.waypoint.timeout;
              obj.link.timeout(delay);
              % ��ɫ�ڵ�
%                if isempty(obj.neighbor) == 0
%                    obj.color = [1 1 0];
%                elseif isempty(obj.odmrp) == 0
%                    obj.color = [1 1 0];
%                end
          end
          
          % Э�鳬ʱ ����pkt----------------------------------------
          % Neighbor protocol timeout function
          if isempty(obj.neighbor) == 0 
              [obj.neighbor, pkt] = obj.neighbor.timeout(delay, t);
              if obj.neighbor.result > 0 % ��ʱʱ���ɵ����ݰ�
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
          
          
          % Process outgoing queue ����������
          if obj.queue.NumElements > 0 && obj.link.until <= 0 % ��ֹͬʱ���Ͷ�����ݰ������ֻ��ȴ����ݰ�������       
              pkt = obj.queue.remove();   % fetch IPv6 packet from TX queue         
              obj.link.lastlen = pkt.len; % �������ݰ��ĳ��ȷ�����·��
              type = pkt.getType;         % get the packet type      
              p = p + 1;                  % global increment of packets TX
              
              if obj.link.checkLinkBusy(t) == 1
                  return;
              end
              
              %�����ݰ�
              obj.link.linkLockTx(obj.id, obj.phy.duration(pkt.len), pkt); % enable MAC protocol
              notify(obj,'PacketStart');   % ������ʼ�������ݰ�
                  
              obj.packets.sent = obj.packets.sent + 1; 
              obj.bytes.sent = obj.bytes.sent + pkt.len;
                             
          end       
      end
      
      function send_pkt(obj, pkt)
          %��pkt�м��뷢���ߵ�����ͷ����ߵ��ݶ�ֵ,��
          %disp("������"+obj.id+" x="+obj.x+" y="+obj.y);
          pkt.x = obj.x;
          pkt.y = obj.y;
          pkt.srcId = obj.id;
          pkt.gradient = obj.gradient;
          pkt.backup = obj.backup;
          %
          obj.queue.add(pkt); % ���ǽ��������ݰ�����tx����
      end

      %����pkt
      function rcvd_pkt(obj,src,~)   
          
          pkt = src.link.pkt; % �ӷ��ͽڵ����·����ȡpkt������ɹ�����һ������               
          
          obj.link.linkReleaseRx; % ������һ���ڵ�����ɷ���            
          %fprintf('medium at Node %d, busy=%d, err=%d\r',obj.id, obj.link.busy, obj.link.err);
          
          if obj.link.isBusy == 0 % ��ý����У����ǿ��Խ������ݰ�             
              %�����ھ���Ϣ,��
              obj.Neighbors(pkt.srcId,1) = pkt.x;
              obj.Neighbors(pkt.srcId,2) = pkt.y;
              obj.Neighbors(pkt.srcId,3) = pkt.gradient;
              fprintf('%d send hello to %d\r\n',pkt.srcId,obj.id);  
              %ʹ���ݶ���ɢ�����������ݶ�
              
              %����ǰ�ڵ��ǹؼ��ڵ㣬��������ھӽڵ�ľ���
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

                  %ѡ��ǰʱ�̵ı��ݽڵ�
                  tmp = Inf;
                  for i=1:size(dist,1)
                      if (obj.Neighbors(i,3)+dist(i,1))<tmp
                          tmp = obj.Neighbors(i,3)+dist(i,1);
                          obj.curBackup = i;
                      end
                  end

                  preGradient = obj.gradient;
                  obj.gradient =  min(obj.gradient,min(obj.Neighbors(:,3)+dist));

                  if preGradient == obj.gradient %��α�ʱ�̵��ݶ�����ʱ�̵��ݶ�һ������������
                      obj.backup = obj.curBackup;
                      obj.stable = 1;
                  else
                      obj.stable = 0;
                  end
              else
                  obj.stable = 1;  
              end
              
              %fprintf('rcvd_pkt, %d from %d, pkt.next: %s��src.x: %d,src.y:%d\r\n', obj.id, src.id, pkt.next,pkt.x,pkt.y);    
              %              
              % ����ͳ������
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
          %���崥�����ݰ������¼�
          notify(obj,'PacketSent'); 
          
          %��ע�͵�����
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
      
      % ���䣬��
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

