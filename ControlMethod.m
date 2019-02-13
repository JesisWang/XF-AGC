function [BatPower,status] = ControlMethod(Agc,Pdg,BatSoc)
% function [BatPower,status] = BatAgcMethod(Agc,Pdg,BatSoc,Verbose)
%
% 本函数旨在实现储能AGC算法，即根据AGC功率限值和机组功率求解需储能总出力并输出。
% 输入：
%	Agc：   标量，表示AGC功率限值，由调度给定，单位：MW。
%	Pdg：   标量，表示发电机组实测功率值，单位：MW。
%   BatSoc：     标量，电池可用容量，0～100，单位：%。
%   Verbose：    标量，表示告警显示等级，0-9，9显示最多告警，0不显示告警。
% 输出：
%	BatPower：	标量，表示储能总功率，单位：MW，放电为正。
%	status：     标量，表示函数的返回状态，>=0表示正常，<0表示异常。
% 版本：最后修改于 2016-09-13
% 2016-09-13 HB
% 2019-01-02 wby
% 1. 建立函数，定义输入输出，编制程序，撰写注释。
% 全局变量定义
global T             % 全局时间
global PdgStart      % 起始出力
global AgcStart      % 起始Agc
global LastAgc       % 上一次调节的Agc
global Tstart        % 起始时间
global Pdg_adj_start % 机组的出死区后的起始出力
global fang          % 调节方向
global lastPdg       % 上一时刻的储能出力
global T_fantiao     % 反调时间
global T_butiao      % 不调时间
global T_huantiao    % 缓调时间
global lastPall      % 上一时刻的联合出力
global T_record      % 缓调记录 起始时刻
global Pdg_record    % 机组功率：历史1小时记录
global flag          % 机组不调记录标志
global SigFM         % 一次调频信号
global Agc_adj       % 实际响应指标

T01=5;% 最小出响应死区时间
T02=3;% 响应死区分段考略，避免踩中临界范围点上，致使调度错误判断
ParaSOC=[50 15 85 10];
% ParaSoc=[期望值 下限 上限 滞环大小]

deadK3=0.01;
Prgen=300;
Pmax=9;
Cdead=0.01;
Cdead_Res=0.025;
Flag_adj=1; % 是否响应后续的标志位,1响应,0不响应
Portion_adj=1; % 响应比例
% if T==1
%    放在函数外
%     lastPdg=0;
%     lastPall=0;
% end
if abs(Agc-AgcStart)>Cdead*Prgen % 固定大小:1 % 区间大小:Cdead*Prgen
    % 新来了一条指令，需要更新初始状态
    PdgStart=Pdg;% 初始的机组功率
    LastAgc=AgcStart;
    AgcStart=Agc;% 初始的AGC功率
    Tstart=T;% 初始的机组功率
    T_fantiao=0;
    T_butiao=0;
    if PdgStart<AgcStart
        fang=1;% 升出力
    else
        fang=-1;
    end
    Agc_adj=(AgcStart-PdgStart)*Portion_adj+PdgStart;
end
% DetP=AgcStart-Pdg;% 调节深度
Vresp_ideal=PdgStart*deadK3/T01;% 理想的响应死区速度
Vn=0.015*Prgen;% 标准调节速度MW/min
Vadj_ideal=5*Vn/60;% 理想的调节速度,MW/s
Socflag=0;
Ts=T-Tstart;
if Ts <= T01
    if Ts<=T02
        % 在短时的策略下，暂不考虑机组反调的问题
        if abs(Pdg-PdgStart) < PdgStart*deadK3 % 按2MW算  %死区按照1%算：PdgStart*0.01
            %若联合功率未达到响应死区范围外
            Pall_resp_ideal=PdgStart+fang*Vresp_ideal*Ts;% 理想的联合功率
            if fang>0 && Pdg>Pall_resp_ideal
                Pall_resp_ideal=Pdg;
            elseif fang<0 && Pdg<Pall_resp_ideal
                Pall_resp_ideal=Pdg;
            end
            BatPower=Pall_resp_ideal-Pdg;% 储能出力
            if BatSoc<ParaSOC(2)
                BatPower=min(BatPower,0);% 超下限，只能充不能放
                Socflag=1;% Soc维护标志
            end
            if BatSoc>ParaSOC(3)
                BatPower=max(BatPower,0);% 超上限，只能放不能冲
                Socflag=1;% Soc维护标志
            end
        else
            Pall_resp_ideal=PdgStart+(PdgStart*deadK3+0.5)*fang;% 理想的联合功率
            BatPower=Pall_resp_ideal-Pdg;% 储能出力
            if BatSoc<ParaSOC(2)
                BatPower=min(BatPower,0);% 超下限，只能充不能放
                Socflag=1;% Soc维护标志
            end
            if BatSoc>ParaSOC(3)
                BatPower=max(BatPower,0);% 超上限，只能放不能冲
                Socflag=1;% Soc维护标志
            end
        end
    else
        Pall_resp_ideal=PdgStart+(PdgStart*deadK3+0.5*(Ts-T02+1))*fang;% 理想的联合功率
        BatPower=Pall_resp_ideal-Pdg;% 储能出力
        if BatSoc<ParaSOC(2)
            BatPower=min(BatPower,0);% 超下限，只能充不能放
            Socflag=1;% Soc维护标志
        end
        if BatSoc>ParaSOC(3)
            BatPower=max(BatPower,0);% 超上限，只能放不能冲
            Socflag=1;% Soc维护标志
        end
    end
else
    if Flag_adj==1
        if Ts == T01+1
            Pdg_adj_start=Pdg;
        end
        Pall_adj_ideal=Pdg_adj_start+fang*Vadj_ideal*(Ts-T01);
        BatPower=Pall_adj_ideal-Pdg;% 储能出力
        if BatSoc<ParaSOC(2)
            BatPower=min(BatPower,0);% 超下限，只能充不能放
            Socflag=1;% Soc维护标志
        end
        if BatSoc>ParaSOC(3)
            BatPower=max(BatPower,0);% 超上限，只能放不能冲
            Socflag=1;% Soc维护标志
        end
        if BatSoc<ParaSOC(3) && BatSoc>ParaSOC(2)
            % 储能SOC正常
            if abs(Agc_adj-Pdg)<Cdead_Res*Prgen
                % 在部分响应出力时，机组到达设定值后，储能退出
                % 机组出力到达调节死区，进行SOC补偿维护
                BatPower=Agc_adj-Pdg;
                if BatSoc<ParaSOC(1)-ParaSOC(4)
                    BatPower=min(BatPower,BatPower/2);% 在目标区域以下，尽量充少放
                    Socflag=1;% Soc维护标志
                end
                if BatSoc>ParaSOC(1)+ParaSOC(4)
                    BatPower=max(BatPower,BatPower/2);% 在目标区域以上，尽量放少充
                    Socflag=1;% Soc维护标志
                end
            else
                % 机组未到达响应设定值，但联合到达设定值
                % 机组未到达死区，但期望联合到达死区
                if abs(Pall_adj_ideal-Agc_adj)<Cdead_Res*Prgen
                    Pall_adj_ideal=Agc_adj-fang*Cdead_Res*Prgen;
                    BatPower=Pall_adj_ideal-Pdg;% 储能出力
                end
                % 机组未到达响应设定值，联合也未到达设定值
                % 机组出力未达到死区，期望联合也未到达死区
                if (Pdg-lastPdg)*fang<0
                    % 机组反调
                    T_fantiao=T_fantiao+1;
                    if T_fantiao>30
                        % 30s反调
                        BatPower=0.8*(lastPall-lastPdg);% 以每秒20%退出
                    end
                else
                    if T_fantiao>0
                        T_fantiao=T_fantiao-1;
                    else
                        T_fantiao=0;
                    end
                    if T_record==0
                        if abs(Pdg-lastPdg)<Prgen*0.001
                            T_record=T;
                            T_butiao=T_butiao+1;
                        end
                    else
                        if abs(Pdg-lastPdg)*fang<3.5 %0.003*Prgen/60
                            % (标准调节速率的20%)
                            % 机组不反调情况下，基本不调
                            T_butiao=T_butiao+1;
                            a=find(Pdg_record~=0,1,'last');
                            if T_butiao>200 && abs(Pdg_record(a)-Pdg_record(a-100))<3.75
                                % 始末状态在2MW内都算是基本不动
                                BatPower=0.95*(lastPall-lastPdg);% 以每秒5%退出
                                flag=1;
                            end
%                             if (Pdg-lastPdg)*fang<0.03*Prgen/60 %(标准调节速率的20%)
%                                 % 机组不反调情况下，基本不调
%                                 T_butiao=T_butiao+1;
%                                 if T_butiao>100
%                                     BatPower=min(BatPower,Pmax);
%                                     BatPower=max(BatPower,-Pmax);
%                                     BatPower=0.98*BatPower;
%                                     BatPower=0.98.^(T_butiao-100)*BatPower;
%                                     BatPower=0.9*(lastPall-lastPdg);% 以每秒10%缓慢退出
%                                 end
                        else
                            T_record=0;
                            T_butiao=0;
                            flag=0;
                        end
                        if (Pdg-lastPdg)*fang<0.015*Prgen/60*0.75 && flag==0
                            % 机组不反调情况下，缓调，按标准调节速率算的75%算
                            T_huantiao=T_huantiao+1;
                            if T_huantiao>60
                                %                             BatPower=min(BatPower,Pmax);
                                %                             BatPower=max(BatPower,-Pmax);
                                BatPower=0.95*(lastPall-lastPdg);
                                %                             BatPower=0.95.^(T_huantiao-60)*BatPower;
                            end
                        else
                            %                         T_record=0;
                            T_huantiao=0;
                            %                         T_butiao=0;
                        end
                    end
                end
            end
        end
    else
        BatPower=0.9*(lastPall-lastPdg);% 不响应后，缓慢退出
        if abs(BatPower)<0.1
            BatPower=0;
        end
    end
end
if Ts>=0 && Ts<15
    b=lastPall-lastPdg;
    b=0.85*b;
    if b>BatPower && b>0
        BatPower=b;
    elseif b<BatPower && b<0
        BatPower=b;
    end
else
    if abs(BatPower-(lastPall-lastPdg))>2.7
        BatPower=(lastPall-lastPdg)+2.7*BatPower/abs(BatPower);
    end
end
%%% 一次调频信号不响应 %%%
if SigFM==1
    BatPower=(lastPall-lastPdg);
end
BatPower=min(BatPower,Pmax);
BatPower=max(BatPower,-Pmax);
status=Socflag;
lastPdg=Pdg;% 上一秒钟的机组出力
lastPall=BatPower+Pdg;% 上一秒中的联合出力