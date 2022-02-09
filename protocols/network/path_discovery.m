
%路径建立和统计跳数的函数

function [path, hop] = path_discovery(nodes_number, nodes_link, s, d)

visited(1:nodes_number) = 0;   
distance(1:nodes_number) = inf;  
parent(1:nodes_number) = 0;
distance(s) = 0; 

for i = 1:nodes_number   
    temp = [];  
    for h = 1:nodes_number   
        if visited(h) == 0 
            temp=[temp distance(h)];   
        else
            temp=[temp inf];
        end
    end    
        
    [t, u] = min(temp);
    visited(u) = 1;  
    for v = 1:nodes_number 
        if ( ( nodes_link(u, v) + distance(u)) < distance(v) ) 
            distance(v) = distance(u) + nodes_link(u, v); 
            parent(v) = u; 
        end             
    end
end

path = [];
if parent(d) ~= 0 
    t = d;
    path = [d];
    while t ~= s
        p = parent(t);
        path = [p path];
        t = p;      
    end
end

hop = distance(d);

return;

