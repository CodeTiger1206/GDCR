function Neighbors = addNeighbors(A,Coord,id)
%��ÿ���ڵ����һ���ھ���Ϣ
            
[n,n] = size(A);
Neighbors = zeros(n,3);
Neighbors(:,3) = Inf;

for i=1:n
    if A(id,i)==1
        Neighbors(i,1) = Coord(i,1);
        Neighbors(i,2) = Coord(i,2);
    end
end

end

