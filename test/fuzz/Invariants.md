## I Have Two Invariants In Mind For This Project

### 1. Active Auction Invariant
This invariant is when the auction is still ongoing:
1. No one has forfeited yet.
2. The auction is not cancelled.
3. The auction is not yet ended.

The `Auction Contract balance` should always be equal to `total bids + auction price + deposit amount`.
<br>
It means, no one should be able to withdraw or get any amount from the contract while it is still ongoing.

### 2. Completed Auction Invariant
This invariant is when the auction has concluded:
1. One bidder has forfeited;
2. The auction is cancelled, or;
3. The auction has already ended.

The `Auction Contract balance` should mostly be equal to `total amount withdrawables` but with very 
<br>
small and negligible discrepancy due to multiplication and division when calculating the incentives.
