
%������


 clear;
 
 nodes_number  = 50;     
 A = 100;             
 R = 10; 
 
 rand('state', 0);      
 X = rand(1,nodes_number)*A/2;  
 Y = rand(1,nodes_number)*A/2; 
 
fprintf('�������� %d ���ڵ㡣\n',nodes_number);
fprintf('\n');    

 figure(1); 
 clf;
 hold on; 

title('����������AODV·�ɻ��Ʒ���');
xlabel('�ռ������ x  ��λ��m');
ylabel('�ռ������� y  ��λ��m');

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
     
s = input('������Դ�ڵ�ţ�');
d = input('������Ŀ�Ľڵ�ţ�');
fprintf('\n');

if (s<=nodes_number&s>=1)&(d<=nodes_number&d>=1)
    
     [path, hop] = path_discovery(nodes_number, nodes_link, s, d); 

     l=length(path);

       if l==0&s~=d 
           fprintf('Դ�ڵ� %d ��Ŀ�Ľڵ� %d ��·��Ϊ���գ�\n',s,d);
           fprintf('\n');
           plot(X(s), Y(s), 'rp','markersize',15); 
           plot(X(d), Y(d), 'rp','markersize',15);
       elseif l==0&s==d
           fprintf('Դ�ڵ� %d ��Ŀ�Ľڵ� %d Ϊͬһ�ڵ㡣\n',s,d);
           fprintf('����Ϊ %d ��\n',hop);
           fprintf('\n')
           plot(X(d), Y(d), 'rp','markersize',15);
       else fprintf('Դ�ڵ� %d ��Ŀ�Ľڵ� %d ��·��Ϊ��',s,d);
           i=2;
           fprintf('%d', s);
           while i~=l+1
               fprintf(' -> %d', path(i));
               i=i+1;
           end;
           fprintf('\n');
           fprintf('����Ϊ %d ��\n',hop);
           fprintf('\n');
       end;

     if l ~= 0
         for i = 1:(l-1)
             line([X(path(i)) X(path(i+1))], [Y(path(i)) Y(path(i+1))], 'Color','r','LineWidth', 1.50);
         end;
     end;
     
hold off;
 
else fprintf('����ڵ��������������У�\n');
    fprintf('\n'); 
    
end;


 