function [Old,New] = chongzhiAGC(AGC,P,Pall)
% This is the file for calculating the revenue
% AGC  AGC指令
% Pall  联合
% P     机组
% Pbat  储能

global day_agcresult
%%%%%%%单独运行文件时需要加载的资料%%%%%%%%
% clear
% load('XFdata')
% data=XFdata.data1215;
% AGC=data(:,1);
% Pall=data(:,3);
% P=data(:,2);
%%%%%%%单独运行文件时需要加载的资料%%%%%%%%

len=length(AGC);
Result=zeros(1,19);
%Result=[AGC Pt0 T0 Pt1 T1 Pt2 T2 Pt3 T3 Tj Vj detP K1 K2 K3 Kp D  flag Validity];
%Result=[ 1   2  3  4   5  6   7   8  9  10 11  12  13 14 15 16 17  18  19];
ControlNo=1;
Result(ControlNo,1:3)=[AGC(1) Pall(1) 1];
if Result(ControlNo,1)>Result(ControlNo,2)
    % 向上调节
    flag=1;
    Result(ControlNo,18)=flag;
else
    % 向下调节
    flag=-1;
    Result(ControlNo,18)=flag;
end
Pe=300;%机组额定功率
deadzone1=Pe*0.012;%响应死区0.01,2
deadzone2=Pe*0.01;%调节死区0.01,2
% deadzone3=0.01;%指令死区
Vn=Pe*0.015;%标准调节速度MW/min,Pe*0.015
tn=60;%标准调节时间s
detPn=0.008*Pe;%标准调节精度0.01*Pe(3)
scanrate=5;%扫描频率
for i=1:scanrate:len
    if abs(AGC(i)-Result(ControlNo,1))>=2 %deadzone3*Pe %Pe*0.01
        % 当AGC当前值>记录AGC值+2(或者Pe*0.01)，表明AGC发生了动作，可能出现了一条新的AGC
        % 则需要计算上一条AGC的K值，以及判断上一条AGC指令是否有效

        % 记录T3
        % 记录Pt3
        Result(ControlNo,8)=Pall(i-scanrate);
        Result(ControlNo,9)=i-scanrate;
        % 没有寻找到T1，以结束时刻计
        if Result(ControlNo,5)==0
            Result(ControlNo,4)=Pall(i-scanrate);
            Result(ControlNo,5)=i-scanrate;
        end
        % 没有寻找到T2，以结束时刻计
        if Result(ControlNo,7)==0
            Result(ControlNo,6)=Pall(i-scanrate);
            Result(ControlNo,7)=i-scanrate;
        end
        % 如果T2<T1，则将T2=T1
        if Result(ControlNo,7)<Result(ControlNo,5)
            Result(ControlNo,7)=Result(ControlNo,5);
        end
        % 计算调节深度D
        % D=Pt2-Pt0+折返
        if  ControlNo~=1 && Result(ControlNo,18)*Result(ControlNo-1,18)>0 
            % 调节时候非折返
            Result(ControlNo,17)= flag*(Result(ControlNo,6)-Result(ControlNo,2));
        elseif ControlNo==1
            % 第一条指令按非折返计算
            Result(ControlNo,17)= flag*(Result(ControlNo,6)-Result(ControlNo,2));
        else
            % 调节时候为折返
            Result(ControlNo,17)= flag*(Result(ControlNo,6)-Result(ControlNo,2))+Pe*0.02;
        end
        % 计算上一次指令的速度Vj
        if Result(ControlNo,7)-Result(ControlNo,5)~=0
            % 当分子，分母不为0时,按公式计算
            Result(ControlNo,11)= flag*(Result(ControlNo,6)-Result(ControlNo,4))/(Result(ControlNo,7)-Result(ControlNo,5));%MW/s
            Result(ControlNo,11)= Result(ControlNo,11)*60;%MW/min
        else
            % 当分子和分母为0时，按调节深度D/指令时长T计算
            Result(ControlNo,11)= Result(ControlNo,17)/(Result(ControlNo,9)-Result(ControlNo,3));
            Result(ControlNo,11)= Result(ControlNo,11)*60;%MW/min
        end
        % 指令有效性判断
        if Result(ControlNo,9)-Result(ControlNo,3)<=30 ...
            || abs(Result(ControlNo,1)-Result(ControlNo,2))<=Pe*0.01 ...
               || Result(ControlNo,11)>5*Vn
            % 若AGC持续时间<=30s
            % 则指令作废
            % 若起始时刻AGC-Pall<=机组额定容量的1%
            % 则指令作废
            % 若调节速度大于5倍参考速率
            % 则指令作废,重置为0
            Result(ControlNo,:)=0;
            % ControlNo=ControlNo+1;
        else
            %%======= 计算K3 =======%%
            % Tj=T1-T0
            % K3=(0.1,2-Tj/60)
            Result(ControlNo,10)= Result(ControlNo,5)-Result(ControlNo,3);
            Result(ControlNo,15)= max(0.1,2-Result(ControlNo,10)/tn);
            %%======== 计算K1 ========%%
            % K1=Vj/Vn or K1=(0.1,Vj/Vn)
            Result(ControlNo,13)= Result(ControlNo,11)/Vn;
            if Result(ControlNo,13)>4.2 %|| Result(ControlNo,13)<0.1
                Result(ControlNo,13)=0.1;
            end
%             if Result(ControlNo,11)<2*Vn
%                 % 根据统计信息看Vj<2*Vn正常计算，否则为0.1
%                 Result(ControlNo,13)= max(0.1,Result(ControlNo,11)/Vn);
%             else
%                 Result(ControlNo,13)= 0.1;
%             end
%            Result(ControlNo,13)= max(0.1,Result(ControlNo,13));
%            if Result(ControlNo,13)>2
%                Result(ControlNo,13)=2;
%            end
            %%======== 计算K2 ========%%
            % detp=abs(p-agc)*dt/time
            % K2=2-detp/detPn
            if Result(ControlNo,7)- Result(ControlNo,9)~=0
                for m= Result(ControlNo,7):scanrate:Result(ControlNo,9)
                    Result(ControlNo,12)= Result(ControlNo,12)+abs(Pall(m)-Result(ControlNo,1))*scanrate;
                end
                Result(ControlNo,12)=Result(ControlNo,12)/(Result(ControlNo,9)-Result(ControlNo,7));
            else
                Result(ControlNo,12)=abs(Result(ControlNo,8)-Result(ControlNo,1));
            end
            Result(ControlNo,14)=max(0.1,2-Result(ControlNo,12)/detPn);
            %%========= 计算Kp =========%%
            % 计算Kp
            Result(ControlNo,16)=Result(ControlNo,13)*Result(ControlNo,14)*Result(ControlNo,15);
            % 进行下一次的指令计算
            Result(ControlNo,19)=1;
            ControlNo=ControlNo+1;
        end
        Result(ControlNo,1:3)=[AGC(i) Pall(i) i];
        if Result(ControlNo,1)>Result(ControlNo,2)
            % 向上调节
            flag=1;
            Result(ControlNo,18)=flag;
        else
            % 向下调节
            flag=-1;
            Result(ControlNo,18)=flag;
        end
    else
        % 当前AGC<记录AGC值+Pe*0.01，表明调度没有给出新的AGC指令
        % 则继续记录本条记录AGC下的参数点
        if Result(ControlNo,5)==0 && abs(Pall(i)-Result(ControlNo,2))>=deadzone1 %deadzone1*Result(ControlNo,2)
            % （机组i时出力-起始出力）>响应死区 && 之前没有记录过响应信息
            % &&后的作用是只记录一次机信息
            Result(ControlNo,4)=Pall(i);
            Result(ControlNo,5)=i;
        end
        if Result(ControlNo,7)==0 && abs(Pall(i)-Result(ControlNo,1))<=deadzone2 %deadzone1*Result(ControlNo,2)
            % （机组i时出力-AGC指令）<调节死区 && 之前没有记录过调节死区信息
            Result(ControlNo,6)=Pall(i);
            Result(ControlNo,7)=i;
        end
    end
    
    %%%=====最后一组数据的计算=====%%%
    if i>=len-4 && i<=len
        % 记录T3
        % 记录Pt3
        Result(ControlNo,8)=Pall(i);
        Result(ControlNo,9)=i;
        % 没有寻找到T1，以结束时刻计
        if Result(ControlNo,5)==0
            Result(ControlNo,4)=Pall(i);
            Result(ControlNo,5)=i;
        end
        % 没有寻找到T2，以结束时刻计
        if Result(ControlNo,7)==0
            Result(ControlNo,6)=Pall(i);
            Result(ControlNo,7)=i;
        end
        % 计算调节深度D
        if  ControlNo~=1 && Result(ControlNo,18)*Result(ControlNo-1,18)>0 
            % 调节时候非折返
            Result(ControlNo,17)= flag*(Result(ControlNo,8)-Result(ControlNo,2));
        else
            % 调节时候为折返
            Result(ControlNo,17)= flag*(Result(ControlNo,8)-Result(ControlNo,2))+Pe*0.02;
        end
        % 计算上一次指令的速度Vj
        if Result(ControlNo,7)-Result(ControlNo,5)~=0
            % 当分子，分母不为0时,按公式计算
            Result(ControlNo,11)= flag*(Result(ControlNo,6)-Result(ControlNo,4))/(Result(ControlNo,7)-Result(ControlNo,5));%MW/s
            Result(ControlNo,11)=  Result(ControlNo,11)*60;%MW/min
        else
            % 当分子和分母为0时，按调节深度D/指令时长T计算
            Result(ControlNo,11)= Result(ControlNo,17)/(Result(ControlNo,9)-Result(ControlNo,3));
            Result(ControlNo,11)=  Result(ControlNo,11)*60;%MW/min
        end
        % 指令有效性判断
        if Result(ControlNo,9)-Result(ControlNo,3)<=30 ...
            || abs(Result(ControlNo,1)-Result(ControlNo,2))<=Pe*0.01 ...
               || Result(ControlNo,11)>5*Vn
            % 若AGC持续时间<=30
            % 则指令作废
            % 若起始时刻AGC-Pall<=机组额定容量的1%
            % 则指令作废
            % 若调节速度大于5倍参考速率
            % 则指令作废
            Result(ControlNo,:)=0;
            Result(ControlNo,:)=[];
        else
            % 计算K3
            % Tj=T1-T0
            % K3=(0.1,2-Tj/60)
            Result(ControlNo,10)= (Result(ControlNo,5)-Result(ControlNo,3));
            Result(ControlNo,15)= max(0.1,2-Result(ControlNo,10)/60);
            % 计算K1
            % K1=(0.1,Vj/Vn)
            Result(ControlNo,13)= Result(ControlNo,11)/Vn;
            if Result(ControlNo,13)>4.2
                Result(ControlNo,13)=0.1;
            end
%             if Result(ControlNo,11)<2*Vn
%                 % 根据统计信息看Vj<2*Vn正常计算，否则为0.1
%                 Result(ControlNo,13)= max(0.1,Result(ControlNo,11)/Vn);
%             else
%                 Result(ControlNo,13)= 0.1;
%             end
%             Result(ControlNo,13)= max(0.1,Result(ControlNo,11)/Vn);
            % 计算K2
            % detp=abs(p-agc)*dt/time
            % K2=2-detp/detPn
            if Result(ControlNo,7)- Result(ControlNo,9)~=0
                for m= Result(ControlNo,7):scanrate:Result(ControlNo,9)
                    Result(ControlNo,12)= Result(ControlNo,12)+abs(Pall(m)-Result(ControlNo,1))*scanrate;
                end
                Result(ControlNo,12)=Result(ControlNo,12)/(Result(ControlNo,9)-Result(ControlNo,7));
            else
                Result(ControlNo,12)=abs(Result(ControlNo,8)-Result(ControlNo,1));
            end
            Result(ControlNo,14)=max(0.1,2-Result(ControlNo,12)/detPn);
            % 计算Kp
            Result(ControlNo,16)=Result(ControlNo,13)*Result(ControlNo,14)*Result(ControlNo,15);
        end
    end
end
% Mall=D*Kp*5.2
aveK1=mean(Result(:,13));
aveK2=mean(Result(:,14));
aveK3=mean(Result(:,15));
aveKp=aveK1*aveK2*aveK3;
% aveKp=aveK1*aveK2*aveK3;
sumD=sum(Result(:,17));
Mall=sumD*(log(aveKp)+1)*5.2;
Mall0=sumD*aveKp*5.2;

RESULT=Result(Result(:,19)>0,:);
AVEK1=mean(RESULT(RESULT(:,13)>0,13));
if AVEK1>2.1
    AVEK1_a=AVEK1-floor(AVEK1*10)/10+2;
else
    AVEK1_a=AVEK1;
end

AVEK2_a1=mean(RESULT(RESULT(:,13)>0,14));
AVEK2_a=AVEK2_a1;

AVEK3_a1=mean(RESULT(RESULT(:,13)>0,15));
if AVEK3_a1>1.7
    AVEK3_a=AVEK3_a1-floor(AVEK3_a1*10)/10+1.6;
else
    AVEK3_a=AVEK3_a1;
end
% aveKp=aveK1*aveK2*aveK3;
AVEKp=AVEK3_a*AVEK2_a*AVEK1_a;
sumD=sum(RESULT(:,17));
MALL=sumD*(log(AVEKp)+1)*5.2;
MALL0=sumD*AVEKp*5.2;
% 考核电量
% if aveK1<1
%     K1kaohe=(1-aveK1)*Pe*2;
% end
% if aveK2<1
%     K2kaohe=(1-aveK2)*Pe*2;
% end
% if aveK1<1
%     K3kaohe=(1-aveK3)*Pe*2;
% end

%% AGC指令强度分析
ResultAGC=zeros(96,8); % 每15分钟考察一次
% ResultAGC=[       1               2                3              4           5              6               7           8        9            10]
% ResultAGC=[15min内最大指令 15min内最小指令 15min的平均指令值 时段起始AGC 时段结束AGC 最大连续爬升或下降 连续持续时间 折返次数 指令条数 指令平均持续时间]
for i=1:900:86400
    N=(i-1)/900+1;
    ResultAGC(N,1)=max(AGC(i:i+899)); % 15min内最大指令
    ResultAGC(N,2)=min(AGC(i:i+899)); % 15min内最小指令
    ResultAGC(N,3)=mean(AGC(i:i+899));% 15min的平均指令值
    Record=zeros(10,4);
%   Record=[AGC i0 iend flag]
    Record(1,1)=AGC(i);
    Record(1,2)=i;
    ctl=1;
    for j=i:i+899
        if abs(AGC(j)-Record(ctl,1))>2
            Record(ctl,3)=j-1;
            ctl=ctl+1;
            Record(ctl,1)=AGC(j);
            Record(ctl,2)=j;
        end
    end
    Plus=0;Minus=0;Tplus=0;Tminus=0;
    for j=2:ctl-1
        if Record(j,1)>Record(j-1,1)
            Plus=Plus+(Record(j,1)-Record(j-1,1));
            Tplus=Tplus+(Record(j,3)-Record(j-1,2));
            Record(j,4)=1;
            Minus=0;
            Tminus=0;
        else
            Plus=0;
            Tplus=0;
            Record(j,4)=-1;
            Minus=Minus+(Record(j,1)-Record(j-1,1));
            Tminus=Tminus+(Record(j,3)-Record(j-1,2));
        end
        if Plus>-Minus
            Tm=Tplus;
            Pm=Plus;
        else
            Tm=Tminus;
            Pm=-Minus;
        end
        if Pm>ResultAGC(N,4)
            ResultAGC(N,6)=Pm; % 最大连续爬升或下降
            ResultAGC(N,7)=Tm; % 最大连续爬坡持续时间
        end
    end
    Turnb=Record(1:(end-1),4).*Record(2:end,4);
    ResultAGC(N,4)=Record(1,1);
    ResultAGC(N,5)=Record(ctl,1);
    ResultAGC(N,8)=sum(Turnb<0); % 折返次数
    ResultAGC(N,9)=ctl;
    ResultAGC(N,10)=mean(Record(1:ctl-1,3)-Record(1:ctl-1,2));
end
No_AGC=size(Result);
No_AGC=No_AGC(1); % AGC的有效调节次数
TurnB=Result(1:(end-1),18).*Result(2:end,18); % 折返调节
No_TurnB_AGC=abs(sum(TurnB<0)); % 有效的折返调节次数.
Range_AGC=abs(Result(:,1)-Result(:,2)); % AGC每次的调节幅度
Ave_ran_AGC=mean(Range_AGC); % 日内平均调节幅度
Ave_Time=mean(Result(:,9)-Result(:,3)); % AGC指令的平均调节时长
day_agcresult=[No_AGC No_TurnB_AGC Ave_ran_AGC Ave_Time];
%% 储能电站的调节强度分析
Pedg=7;
Pbat=Pall-P;
Plus_Pdg=sum(Pbat(Pbat>0));  % 正向累积放电功率,MW
Minus_Pdg=sum(Pbat(Pbat<0));  % 负向累积充电功率
PlusE_Pdg=Plus_Pdg/3600;  % 正向累积放电电量,MWh
MinusE_Pdg=Minus_Pdg/3600;  % 负向累积放电电量
Eqv_Cycplus=PlusE_Pdg/(Pedg); % 等效循环次数(放空）
Eqv_Cycminus=MinusE_Pdg/(Pedg); % 等效循环次数（充满）
Initial_SOC=20;
Bat=zeros(len,3);
% Bat = [       1              2                 3]
% Bat = [ 储能充放功率    每次充放倍率     每次充放电量
BatResult=zeros(10,8); % 电池的计算结果
% BatResult=[    1           2                  3                    4                  5               6          7            8];
% BatResult=[记录AGC  正向调节功率总和  负向调节功率总和     等效以2C放电时长    等效以2C充电时长   放电深度  累计放电深度  剩余SOC];
% 每次AGC指令来时的功率
Bat(:,1)=Pbat;
Bat(:,2)=Bat(:,1)/Pedg;
Bat(:,3)=Bat(:,1)/3600;% 放电电量，单位MWh
CtrlNo=1;
BatResult(CtrlNo,1)=AGC(1);
BatResult(CtrlNo,8)=Initial_SOC;
for i=1:scanrate:86400
    if abs(AGC(i)-BatResult(CtrlNo,1))>=2 %deadzone3*Pe %Pe*0.01
        % 当AGC当前值>记录AGC值+2(或者Pe*0.01)，表明AGC发生了动作，可能出现了一条新的AGC
        % 则需要计算上一条AGC下的储能消耗
        BatResult(CtrlNo,4)=BatResult(CtrlNo,2)/(2*Pedg);% 单位s
        BatResult(CtrlNo,5)=BatResult(CtrlNo,3)/(2*Pedg);% 单位s
        BatResult(CtrlNo,6)=BatResult(CtrlNo,6)/Pedg*100;% 单位%
        if CtrlNo == 1
            BatResult(CtrlNo,7)=BatResult(CtrlNo,6);% 单位%
            BatResult(CtrlNo,8)=BatResult(CtrlNo,8)-BatResult(CtrlNo,6);
        else
            BatResult(CtrlNo,7)=BatResult(CtrlNo-1,7)+BatResult(CtrlNo,6);
            BatResult(CtrlNo,8)=BatResult(CtrlNo-1,8)-BatResult(CtrlNo,6);
        end
        CtrlNo=CtrlNo+1;
        BatResult(CtrlNo,1)=AGC(i);
    else
        % 如果AGC指令不发生变化，则计算累计储能的结果
        if Bat(i,1)>0
            BatResult(CtrlNo,2)=BatResult(CtrlNo,2)+Bat(i,1)*scanrate;%单位MW，此时的scanrate代表次数，即5次该功率
        end
        if Bat(i,1)<0
            BatResult(CtrlNo,3)=BatResult(CtrlNo,3)+Bat(i,1)*scanrate;
        end
        BatResult(CtrlNo,6)=BatResult(CtrlNo,6)+sum(Bat(i:i+4,1))/3600;%单位MWh
    end
end
Old=[aveK1,aveK2,aveK3,aveKp,sumD,Mall,Mall0,Eqv_Cycplus,Eqv_Cycminus];
New=[AVEK1_a,AVEK2_a,AVEK3_a,AVEKp,sumD,MALL,MALL0,Eqv_Cycplus,Eqv_Cycminus];