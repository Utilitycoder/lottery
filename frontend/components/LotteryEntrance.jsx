import { useWeb3Contract } from "react-moralis";

export default function LotteryEntrance() {

    const { runContractFunction: entranceFee } = useWeb3Contract({
        abi: "",
        contractAddress: "",
        functionName: "",
        params: {},
        msgValue: "",
    })
    return (
        <div>

        </div>
    )
}