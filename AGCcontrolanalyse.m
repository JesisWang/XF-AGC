clear
load('XFdata.mat')
data=XFdata.data1203(:,1:3);
Agc=data(:,1);% AGC指令
P=data(:,2);% 机组出力
Pall=data(:,3);% 联合出力
LineMax=length(Agc);% 一天的数据点的时长
Result=zeros(10,12);% 结果保存数据
% Result=[1         2        3          4          5      6         7          8              9               10             11            12]
% Result=[AGC 机组起始时刻值 t0 机组首次开始动作值 t1 反向记录  不调记录  动作缓慢记录  瞬间调节完成  调节效果（有1,无0）调节方向  机组本身到达死区]
ctrlNo=1;
Result(ctrlNo,1)=Agc(1);
Result(ctrlNo,2)=P(1);
Result(ctrlNo,3)=1;
detAGC=2;% 辨别AGC差别的死区
Prate=300;% 机组功率
Erate=9;
T1=0;% 反调计时
Cdead=2;
T2i=0;% 不调起始时刻，为了保证连续一段时间内均是基本不动作
T2=0;% 不调计时
Tlen=40;
if Result(ctrlNo,1)>Result(ctrlNo,2)
    Result(ctrlNo,11)=1;
else
    Result(ctrlNo,11)=-1;
end
tic
for i=1:LineMax
    if (Agc(i) > detAGC+Result(ctrlNo,1)) ||  (Agc(i) < Result(ctrlNo,1)-detAGC)
        % 新来一条指令，核算上调指令的情况
        if Result(ctrlNo,6)==0 && Result(ctrlNo,7)==0 
            % 没有反调或不调,以及机组未到达死区的情况下，计算机组的调节速率是否缓慢
            if (P(i)-Result(ctrlNo,4))/(i-Result(ctrlNo,5))*60<0.015*Prate
                % 若机组调节速率小于标准速率
                if Result(ctrlNo,12)==0
                    % 且机组没有到达调节死区范围内
                    Result(ctrlNo,8)=1;
                end
            end
        end
%         if abs(Pall(i)-Result(ctrlNo,1))<Cdead
%             % 联合出力到达调节范围内，记调节成功一次
%             Result(ctrlNo,10)=1;
%         end
        if Result(ctrlNo,5)==0 
            Result(ctrlNo,7)=1;
        end
        if i-Result(ctrlNo,3)>Tlen
            % 指令持续时长小于40秒，指令作废
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
            % 判断机组开始响应指令时刻
            Result(ctrlNo,4)=P(i);
            Result(ctrlNo,5)=i;
        end
        if Result(ctrlNo,6)==0
            % 机组反向调节
            if i>2 && (P(i)-P(i-1))*(Result(ctrlNo,11))<0
                % 机组出力方向与指令方向相反
                T1=T1+1;
                if T1>=10 && (P(i)-P(i-T1))*Result(ctrlNo,11)<-2
                    % 持续10s即判断是反调
                    Result(ctrlNo,6)=1;
                    T1=0;
                end
            end
        end
        if Result(ctrlNo,7)==0 && Result(ctrlNo,5)~=0
            % 机组不调记录
            if abs(Result(ctrlNo,1)-P(i))>Cdead
                % 机组出力不在调节死区内才正常计数
                if T2i==0
                    if i>2 && abs(P(i)-P(i-1))<0.2
                        % 记录不调起始时刻，并开始计数
                        T2i=i;
                        T2=T2+1;
                    end
                else
                    if i>2 && abs(P(i)-P(i-1))<0.2 && i-T2i==T2
                        % 机组波动死区0.2MW,以免有小幅的波动，导致连续性破坏
                        T2=T2+1;
                        if T2>=Tlen/2 && abs(P(i)-P(i-T2))<0.4
                            % 达到20s后，若此时机组出力相较于起始出力仍在0.4MW内，则记为不调
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
            % 2s内
            if abs(Pall(i)-Result(ctrlNo,1))<1 % && abs(Pall(i))>Erate/2
                % 储能将出力拉至AGC处，并且功率大于0.5倍额定功率
                Result(ctrlNo,9)=1;
            end
        end
        if Result(ctrlNo,12)==0 && abs(Result(ctrlNo,1)-P(i))<Cdead
            Result(ctrlNo,12)=1;
        end
        if abs(Pall(i)-Result(ctrlNo,1))<Cdead && Result(ctrlNo,10)==0
            % 联合出力到达调节范围内，记调节成功一次
            Result(ctrlNo,10)=1;
        end
    end
end
%% 分析
N=length(Result(:,6));
M=0;
Op1=sum(Result(:,6))/N*100 % 机组反调比例
Op2=sum(Result(:,7))/N*100 % 机组长时间不动的比例
Op3=sum(Result(:,8))/N*100 % 机组调节速度小于标准调节速度的比例
Op4=sum(Result(:,9))/N*100 % 2s内将机组出力拉至AGC指令上
S=0;
for i=1:N
    if Result(i,6)==1 || Result(i,7)==1 || Result(i,8)==1
        M=M+1;
        if Result(i,10)==1
            S=S+1;
        end
    end
end
S %代表当前储能调节策略下，在机组出力存在问题的情况下，有效调节（可获Kp值）的次数
S/M*100  %相应比例
toc