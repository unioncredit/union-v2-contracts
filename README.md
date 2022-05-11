# Union Contracts V1.5

## Difference from V1

-   Does not lock interest, only locks principal
-   First in first out locks for vouchers

## Todo

-   [ ] fuzzing tests
-   [ ] test the rest of the code base still works
-   [ ] write getVoucherIndex function and rename voucherIndexes to voucherPositions

## Tests

```
forge test
```

## Compile

```
forge build
```

## Gas

```
forge test --gas-report
forge snapshot
```
