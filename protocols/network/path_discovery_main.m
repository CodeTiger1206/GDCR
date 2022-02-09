
%主程序


 clear;
 
 nodes_number  = 50;     
 A = 100;             
 R = 10; 
 
 rand('state', 0);      
 X = rand(1,nodes_number)*A/2;  
 Y = rand(1,nodes_number)*A/2; 
 
fprintf('此网络有 %d 个节点。\n',nodes_number);
fprintf('\n');    

 figure(1); 
 clf;
 hold on; 

title('无线自组网AODV路由机制仿真');
xlabel('空间横坐标 x  单位：m');
ylabel('空间纵坐标 y  单位：m');

for i = 1:nodes_number
     plot(X(i), Y(i), '.'); 
     text(X(i), Y(i), num2str(i));
     for j = 1:nodes_number
         distance = sqrt((X(i) - X(j))^2 + (Y(i) - Y(j))^2); 
         if distance <= R
             nodes_link(i, j) = 1;
             %line([X(i) X(j)], [Y(i) Y(j)], 'LineStyle', '-.'); 
             grid on;
         else
             nodes_link(i, j) = inf;
         end;
     end;
 end;
     
s = input('请输入源节点号：');
d = input('请输入目的节点号：');
fprintf('\n');

if (s<=nodes_number&s>=1)&(d<=nodes_number&d>=1)
    
     [path, hop] = path_discovery(nodes_number, nodes_link, s, d); 

     l=length(path);

       if l==0&s~=d 
           fprintf('源节点 %d 到目的节点 %d 的路径为：空！\n',s,d);
           fprintf('\n');
           plot(X(s), Y(s), 'rp','markersize',15); 
           plot(X(d), Y(d), 'rp','markersize',15);
       elseif l==0&s==d
           fprintf('源节点 %d 与目的节点 %d 为同一节点。\n',s,d);
           fprintf('跳数为 %d 。\n',hop);
           fprintf('\n')
           plot(X(d), Y(d), 'rp','markersize',15);
       else fprintf('源节点 %d 到目的节点 %d 的路径为：',s,d);
           i=2;
           fprintf('%d', s);
           while i~=l+1
               fprintf(' -> %d', path(i));
               i=i+1;
           end;
           fprintf('\n');
           fprintf('跳数为 %d 。\n',hop);
           fprintf('\n');
       end;

     if l ~= 0
         for i = 1:(l-1)
             line([X(path(i)) X(path(i+1))], [Y(path(i)) Y(path(i+1))], 'Color','r','LineWidth', 1.50);
         end;
     end;
     
hold off;
 
else fprintf('输入节点有误，请重新运行！\n');
    fprintf('\n'); 
    
end;


 