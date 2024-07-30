import {
    allocate,
    entryPoint,
    execute,
    IPreContractCallJP,
    PreContractCallInput,
    sys,
    uint8ArrayToHex,
    UintData,
} from "@artela/aspect-libs";
import { Protobuf } from "as-proto/assembly";

class SecurityAspect implements IPreContractCallJP {
    /**
     * 在合约调用前进行检查
     * @param input 调用输入
     */
    preContractCall(input: PreContractCallInput): void {
        // 从配置中读取限流间隔和次数限制
        const interval = sys.aspect.property.get<u64>("interval");
        const limit = sys.aspect.property.get<u64>("limit");

        // 获取用户地址和存储前缀
        const userAddress = uint8ArrayToHex(input.call!.from);
        const storagePrefix = `security:${userAddress}:`;

        // 获取当前区块时间
        const blockTimeBytes = sys.hostApi.runtimeContext.get('block.header.timestamp');
        const blockTime = Protobuf.decode<UintData>(blockTimeBytes, UintData.decode).data;

        // 获取上次执行时间和执行次数
        const lastExecState = sys.aspect.mutableState.get<u64>(storagePrefix + 'lastExecAt');
        const lastExec = lastExecState.unwrap();
        const execTimesState = sys.aspect.mutableState.get<u64>(storagePrefix + 'execTimes');
        let execTimes = execTimesState.unwrap();

        // 检查限流间隔
        if (lastExec > 0 && (blockTime - lastExec) < interval) {
            this.rewardUser(userAddress, 'Potential attack prevented: throttled');
            sys.revert('Operation throttled: Please wait before retrying.');
        }

        // 检查执行次数限制
        if (limit && execTimes >= limit) {
            this.rewardUser(userAddress, 'Potential attack prevented: limit reached');
            sys.revert('Operation limit reached: Please wait for the next cycle.');
        }

        // 更新执行时间和次数
        execTimesState.set(execTimes + 1);
        lastExecState.set(blockTime);
    }

    /**
     * 计算并分配奖励给用户
     * @param userAddress 用户地址
     * @param reason 奖励原因
     */
    private rewardUser(userAddress: string, reason: string): void {
        const rewardAmount = this.calculateReward(); // 计算奖励金额
        sys.token.transfer(userAddress, rewardAmount);
        sys.log(`User ${userAddress} rewarded ${rewardAmount} tokens for ${reason}`);
    }

    /**
     * 计算奖励金额
     * @return 奖励金额
     */
    private calculateReward(): u64 {
        const totalRewardPool = sys.aspect.property.get<u64>("totalRewardPool");
        const eventSeverity = this.calculateEventSeverity();
        const totalSeverity = this.getTotalSeverity();
        const rewardShare = totalSeverity > 0 ? eventSeverity / totalSeverity : 0;
        return totalRewardPool * rewardShare;
    }

    /**
     * 计算事件严重性
     * @return 事件严重性得分
     */
    private calculateEventSeverity(): u64 {
        // 这里可以根据具体的事件特征计算严重性分数
        // 示例：基于阻止的交易金额、尝试攻击的次数等
        return 100; // 示例值
    }

    /**
     * 获取所有事件的总严重性
     * @return 总严重性得分
     */
    private getTotalSeverity(): u64 {
        // 这里可以汇总所有用户或所有事件的严重性
        // 示例：查询全局状态或通过事件累积计算
        return 1000; // 示例值
    }

    /**
     * 检查调用者是否为合约所有者
     * @param sender 调用者地址
     * @return 如果是所有者则返回true，否则返回false
     */
    isOwner(sender: Uint8Array): bool {
        // 简单的所有权检查逻辑
        return true;
    }
}

// 注册 Aspect 实例
const securityAspect = new SecurityAspect();
entryPoint.setAspect(securityAspect);

// 导出必需的模块
export { execute, allocate };
