clear
load('XFdata.mat')
data=XFdata.data1203(:,1:3);
Agc=data(:,1);% AGCָ��
P=data(:,2);% �������
Pall=data(:,3);% ���ϳ���
LineMax=length(Agc);% һ������ݵ��ʱ��
Result=zeros(10,12);% �����������
% Result=[1         2        3          4          5      6         7          8              9               10             11            12]
% Result=[AGC ������ʼʱ��ֵ t0 �����״ο�ʼ����ֵ t1 �����¼  ������¼  ����������¼  ˲��������  ����Ч������1,��0�����ڷ���  ���鱾��������]
ctrlNo=1;
Result(ctrlNo,1)=Agc(1);
Result(ctrlNo,2)=P(1);
Result(ctrlNo,3)=1;
detAGC=2;% ���AGC��������
Prate=300;% ���鹦��
Erate=9;
T1=0;% ������ʱ
Cdead=2;
T2i=0;% ������ʼʱ�̣�Ϊ�˱�֤����һ��ʱ���ھ��ǻ���������
T2=0;% ������ʱ
Tlen=40;
if Result(ctrlNo,1)>Result(ctrlNo,2)
    Result(ctrlNo,11)=1;
else
    Result(ctrlNo,11)=-1;
end
tic
for i=1:LineMax
    if (Agc(i) > detAGC+Result(ctrlNo,1)) ||  (Agc(i) < Result(ctrlNo,1)-detAGC)
        % ����һ��ָ������ϵ�ָ������
        if Result(ctrlNo,6)==0 && Result(ctrlNo,7)==0 
            % û�з����򲻵�,�Լ�����δ��������������£��������ĵ��������Ƿ���
            if (P(i)-Result(ctrlNo,4))/(i-Result(ctrlNo,5))*60<0.015*Prate
                % �������������С�ڱ�׼����
                if Result(ctrlNo,12)==0
                    % �һ���û�е������������Χ��
                    Result(ctrlNo,8)=1;
                end
            end
        end
%         if abs(Pall(i)-Result(ctrlNo,1))<Cdead
%             % ���ϳ���������ڷ�Χ�ڣ��ǵ��ڳɹ�һ��
%             Result(ctrlNo,10)=1;
%         end
        if Result(ctrlNo,5)==0 
            Result(ctrlNo,7)=1;
        end
        if i-Result(ctrlNo,3)>Tlen
            % ָ�����ʱ��С��40�룬ָ������
            ctrlNo=ctrlNo+1;
            Result(ctrlNo,1)=Agc(i);
            Result(ctrlNo,2)=P(i);
            Result(ctrlNo,3)=i;
            if Result(ctrlNo,1)>Result(ctrlNo,2)
                Result(ctrlNo,11)=1;
            else
                Result(ctrlNo,11)=-1;
            end
            T1=0;
            T2i=0;
            T2=0;
        else
            Result(ctrlNo,:)=0;
            Result(ctrlNo,1)=Agc(i);
            Result(ctrlNo,2)=P(i);
            Result(ctrlNo,3)=i;
            if Result(ctrlNo,1)>Result(ctrlNo,2)
                Result(ctrlNo,11)=1;
            else
                Result(ctrlNo,11)=-1;
            end
            T1=0;
            T2i=0;
            T2=0;
        end
    else
        if abs(P(i)-Result(ctrlNo,2))>0.3 && Result(ctrlNo,5)==0
            % �жϻ��鿪ʼ��Ӧָ��ʱ��
            Result(ctrlNo,4)=P(i);
            Result(ctrlNo,5)=i;
        end
        if Result(ctrlNo,6)==0
            % ���鷴�����
            if i>2 && (P(i)-P(i-1))*(Result(ctrlNo,11))<0
                % �������������ָ����෴
                T1=T1+1;
                if T1>=10 && (P(i)-P(i-T1))*Result(ctrlNo,11)<-2
                    % ����10s���ж��Ƿ���
                    Result(ctrlNo,6)=1;
                    T1=0;
                end
            end
        end
        if Result(ctrlNo,7)==0 && Result(ctrlNo,5)~=0
            % ���鲻����¼
            if abs(Result(ctrlNo,1)-P(i))>Cdead
                % ����������ڵ��������ڲ���������
                if T2i==0
                    if i>2 && abs(P(i)-P(i-1))<0.2
                        % ��¼������ʼʱ�̣�����ʼ����
                        T2i=i;
                        T2=T2+1;
                    end
                else
                    if i>2 && abs(P(i)-P(i-1))<0.2 && i-T2i==T2
                        % ���鲨������0.2MW,������С���Ĳ����������������ƻ�
                        T2=T2+1;
                        if T2>=Tlen/2 && abs(P(i)-P(i-T2))<0.4
                            % �ﵽ20s������ʱ��������������ʼ��������0.4MW�ڣ����Ϊ����
                            Result(ctrlNo,7)=1;
                            T2=0;
                            T2i=0;
                        end
                    else
                        T2=0;
                        T2i=0;
                    end
                end
            end
        end
        if i-Result(ctrlNo,3)<=2
            % 2s��
            if abs(Pall(i)-Result(ctrlNo,1))<1 % && abs(Pall(i))>Erate/2
                % ���ܽ���������AGC�������ҹ��ʴ���0.5�������
                Result(ctrlNo,9)=1;
            end
        end
        if Result(ctrlNo,12)==0 && abs(Result(ctrlNo,1)-P(i))<Cdead
            Result(ctrlNo,12)=1;
        end
        if abs(Pall(i)-Result(ctrlNo,1))<Cdead && Result(ctrlNo,10)==0
            % ���ϳ���������ڷ�Χ�ڣ��ǵ��ڳɹ�һ��
            Result(ctrlNo,10)=1;
        end
    end
end
%% ����
N=length(Result(:,6));
M=0;
Op1=sum(Result(:,6))/N*100 % ���鷴������
Op2=sum(Result(:,7))/N*100 % ���鳤ʱ�䲻���ı���
Op3=sum(Result(:,8))/N*100 % ��������ٶ�С�ڱ�׼�����ٶȵı���
Op4=sum(Result(:,9))/N*100 % 2s�ڽ������������AGCָ����
S=0;
for i=1:N
    if Result(i,6)==1 || Result(i,7)==1 || Result(i,8)==1
        M=M+1;
        if Result(i,10)==1
            S=S+1;
        end
    end
end
S %����ǰ���ܵ��ڲ����£��ڻ�������������������£���Ч���ڣ��ɻ�Kpֵ���Ĵ���
S/M*100  %��Ӧ����
toc