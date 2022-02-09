function ans = isCritical(Neighbors,radio)
%根据一跳邻居信息判断该节点是否属于关键节点
%每个节点根据邻居的位置信息在本地确定它是否重要。
%它根据邻居的位置计算他们之间的距离。如果距离小于他们的通信范围，则节点被认为是非关键的，

neighbors = [];
for i=1:size(Neighbors,1)
    if Neighbors(i,1)~=0 && Neighbors(i,2)~=0
        neighbors = [neighbors;[Neighbors(i,1) Neighbors(i,2)]];
    end
end

[m,n] = size(neighbors);
if m==0 || m==1 %如何只有一个邻居则该节点不属于关键节点
    ans = 0;
    return;
end

A = zeros(m); %创建所有邻居节点的邻接矩阵

for i=1:m
    for j=1:m
        if i~=j
            x1 = neighbors(i,1);
            y1 = neighbors(i,2);
            x2 = neighbors(j,1);
            y2 = neighbors(j,2);

            range=sqrt((x2-x1)^2+(y2-y1)^2);
            if (range)<radio 
                A(i,j)=1;
            else        
                A(i,j)=0;
            end
        else
            A(i,i)=0;
        end
    end
end

P = canget(A);
if all(P(:)==1)==0 %判断连通性
    ans = 1; %若所有的一跳邻居之间不连通，则该节点是关键节点
else
    ans = 0; %若所有的一跳邻居之间连通，则该节点不是关键节点
end

end

