//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

contract Sort {
    struct LockedInfo {
        string user;
        uint256 amount;
    }

    function quick(LockedInfo[] memory data) public pure returns (LockedInfo[] memory) {
        if (data.length > 1) {
            quickPart(data, 0, data.length - 1);
        }
        return data;
    }

    function quickPart(
        LockedInfo[] memory data,
        uint256 low,
        uint256 high
    ) internal pure {
        if (low < high) {
            LockedInfo memory pivotVal = data[(low + high) / 2];

            uint256 low1 = low;
            uint256 high1 = high;
            for (;;) {
                while (data[low1].amount < pivotVal.amount) low1++;
                while (data[high1].amount > pivotVal.amount) high1--;
                if (low1 >= high1) break;
                (data[low1], data[high1]) = (data[high1], data[low1]);
                low1++;
                high1--;
            }
            if (low < high1) quickPart(data, low, high1);
            high1++;
            if (high1 < high) quickPart(data, high1, high);
        }
    }

    function insertion(LockedInfo[] memory data) public pure returns (LockedInfo[] memory) {
        uint256 length = data.length;
        int256 preIndex;
        LockedInfo memory current;
        for (uint256 i = 1; i < length; i++) {
            preIndex = int256(i - 1);
            current = data[i];
            while (preIndex >= 0 && data[uint256(preIndex)].amount > current.amount) {
                data[uint256(preIndex + 1)] = data[uint256(preIndex)];
                preIndex--;
            }
            data[uint256(preIndex + 1)] = current;
        }
        return data;
    }

    function selection(LockedInfo[] memory data) public pure returns (LockedInfo[] memory) {
        uint256 length = data.length;
        uint256 minIndex;
        LockedInfo memory temp;
        for (uint256 i = 0; i < length - 1; i++) {
            minIndex = i;
            for (uint256 j = i + 1; j < length; j++) {
                if (data[j].amount < data[minIndex].amount) {
                    minIndex = j;
                }
            }
            temp = data[i];
            data[i] = data[minIndex];
            data[minIndex] = temp;
        }
        return data;
    }

    function bubble(LockedInfo[] memory data) public pure returns (LockedInfo[] memory) {
        uint256 length = data.length;
        for (uint256 i = 0; i < length; i++) {
            for (uint256 j = i + 1; j < length; j++) {
                if (data[i].amount > data[j].amount) {
                    LockedInfo memory temp = data[j];
                    data[j] = data[i];
                    data[i] = temp;
                }
            }
        }
        return data;
    }

    //InPlace Merge
    function merge(
        LockedInfo[] memory arr,
        uint256 start,
        uint256 mid,
        uint256 end
    ) public pure returns (LockedInfo[] memory) {
        uint256 start2 = mid + 1;

        // If the direct merge is already sorted
        if (arr[mid].amount > arr[start2].amount) {
            // Two pointers to maintain start
            // of both arrays to merge
            while (start <= mid && start2 <= end) {
                // If element 1 is in right place
                if (arr[start].amount <= arr[start2].amount) {
                    start++;
                } else {
                    LockedInfo memory value = arr[start2];
                    uint256 index = start2;

                    // Shift all the elements between element 1
                    // element 2, right by 1.
                    while (index != start) {
                        arr[index] = arr[index - 1];
                        index--;
                    }
                    arr[start] = value;

                    // Update all the pointers
                    start++;
                    mid++;
                    start2++;
                }
            }
        }
        return arr;
    }

    function inPlaceMerge(
        LockedInfo[] memory arr,
        uint256 l,
        uint256 r
    ) public pure returns (LockedInfo[] memory) {
        if (l < r) {
            uint256 m = l + (r - l) / 2;
            inPlaceMerge(arr, l, m);
            inPlaceMerge(arr, m + 1, r);
            merge(arr, l, m, r);
        }

        return arr;
    }

    function oddEvenSort(LockedInfo[] memory arr, uint256 n) public pure returns (LockedInfo[] memory) {
        if (arr.length == 0 || arr.length == 1) return arr;
        // Initially array is unsorted
        bool isSorted = false;
        while (!isSorted) {
            isSorted = true;
            LockedInfo memory temp;
            // Perform Bubble sort on odd indexed element
            for (uint256 i = 1; i <= n - 2; i = i + 2) {
                if (arr[i].amount > arr[i + 1].amount) {
                    temp = arr[i];
                    arr[i] = arr[i + 1];
                    arr[i + 1] = temp;
                    isSorted = false;
                }
            }

            // Perform Bubble sort on even indexed element
            for (uint256 i = 0; i <= n - 2; i = i + 2) {
                if (arr[i].amount > arr[i + 1].amount) {
                    temp = arr[i];
                    arr[i] = arr[i + 1];
                    arr[i + 1] = temp;
                    isSorted = false;
                }
            }
        }

        return arr;
    }

    /*
    function gasCost(string memory name, function(LockedInfo[] memory data) internal returns(LockedInfo[] memory) fun, LockedInfo[] memory data)
        internal returns(LockedInfo[] memory arr)
    {
        uint256 u0 = gasleft();
        arr = fun(data);
        uint256 u1 = gasleft();
        uint256 diff = u0 - u1;
    }

    function gasCost2(string memory name, function(LockedInfo[] memory data, uint256 n) internal returns(LockedInfo[] memory) fun, LockedInfo[] memory data, uint256 n)
        internal returns(LockedInfo[] memory arr)
    {
        uint256 u0 = gasleft();
        arr = fun(data,n);
        uint256 u1 = gasleft();
        uint256 diff = u0 - u1;
    }

    function gasCost3(string memory name, function(LockedInfo[] memory data, uint256 l, uint256 r) internal returns(LockedInfo[] memory) fun, LockedInfo[] memory data, uint256 l, uint256 r)
        internal returns(LockedInfo[] memory arr)
    {
        uint256 u0 = gasleft();
        arr = fun(data,l,r);
        uint256 u1 = gasleft();
        uint256 diff = u0 - u1;
    }

    function cloneData(LockedInfo[] memory data) public returns (LockedInfo[] memory) {
      LockedInfo[] memory copy = new LockedInfo[](data.length);
      for (uint i = 0; i < data.length; i++) {
        copy[i] = LockedInfo(data[i].user, data[i].amount);
      }
      return copy;
    }

    function gasCostSortInsertion(LockedInfo[] memory data) public returns(LockedInfo[] memory){
        // gasCost("quick", quick, cloneData(data));
        // gasCost("selection", selection, cloneData(data));
        gasCost("insertion", insertion, cloneData(data));
        gasCost("bubble", bubble, cloneData(data));
        gasCost2("oddEvenSort", oddEvenSort, cloneData(data), data.length);
        gasCost3("inPlaceMerge", inPlaceMerge, cloneData(data), 0, data.length-1);     
    }
    */
}
