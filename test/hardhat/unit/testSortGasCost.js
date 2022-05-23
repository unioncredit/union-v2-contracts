const {ethers} = require("hardhat");
require("chai").should();

const showArray = res => {
    let array = [];
    for (let i = 0; i < res.length; i++) {
        array.push({
            user: res[i].user,
            amount: res[i].amount.toString()
        });
    }
    console.log(array);
};

describe("Sort Contract", async () => {
    // let sortContract;
    // before(async () => {
    //     const Sort = await ethers.getContractFactory("Sort");
    //     sortContract = await Sort.deploy();
    // });
    // it("Test Sort Gas Cost", async () => {
    //     const counts = [3, 5, 10, 25, 50, 75, 100];
    //     let arr;
    //     for (let i = 0; i < counts.length; i++) {
    //         console.log("************");
    //         console.log(`params length: ${counts[i]}`);
    //         console.log("random");
    //         arr = new Array(counts[i]);
    //         for (let j = 0; j < arr.length; j++) {
    //             arr[j] = {
    //                 user: "user_" + j,
    //                 amount: ethers.utils.parseEther(parseInt(Math.random() * 100).toString())
    //             };
    //         }
    //         await sortContract.gasCostSortInsertion(arr);
    //         console.log("reverse");
    //         arr = new Array(counts[i]);
    //         for (let j = 0; j < arr.length; j++) {
    //             arr[j] = {
    //                 user: "user_" + j,
    //                 amount: ethers.utils.parseEther(parseInt(arr.length - j).toString())
    //             };
    //         }
    //         await sortContract.gasCostSortInsertion(arr);
    //     }
    // });
    // it("Test insertion and inPlaceMerge sort results", async () => {
    //     let count = 100;
    //     let arr;
    //     arr = new Array(count);
    //     for (let i = 0; i < arr.length; i++) {
    //         arr[i] = {
    //             user: "user_" + i,
    //             amount: ethers.utils.parseEther(parseInt(Math.random() * 10).toString()) //Ensure enough repetitions to verify the order of the same amount
    //         };
    //     }
    //     console.log("insertion");
    //     res = await sortContract.insertion(arr);
    //     showArray(res);
    //     console.log("inPlaceMerge");
    //     res2 = await sortContract.inPlaceMerge(arr, 0, arr.length - 1);
    //     showArray(res2);
    //     if (res.length != res2.length) throw new Error("Inconsistent ordering");
    //     for (let i = 0; i < res.length; i++) {
    //         if (res[i].user != res2[i].user || res[i].amount.toString() != res2[i].amount.toString()) {
    //             console.log(i, res[i].user, res[i].amount.toString());
    //             console.log(i, res2[i].user, res2[i].amount.toString());
    //             throw new Error("Inconsistent ordering");
    //         }
    //     }
    // });
});
