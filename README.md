# wb-vrf-coinflip
Temporary repository for WB Coinflip contracts RND and testing

## Overview
1. User call coinFlip with 'choice' params, indicating coin sides user chose to bet on. The bet's details will be stored in requestIdToFlipStructs
2. On the callback function, checkFlip function will verify and determine if a specific bet is winning or losing
3. Based on the winning status the contract has to transfer the exact amount to burn, to store in treasury, and to give back to user as reward (if winning)

## V1
Deployed address: 0xe17850148C38BaD450add174322BAfd3356B5adD
This is the working version we're using currenly using for staging

## V2
Deployed address: 0xFcAFEd21C25aB954224dFAE5e85259b03579AD0a
 
Changes:
1. We've moved 'transfer to burner address' process outside the callback function. The burnTax function will be called periodically by our team or using CRON
2. We've added 'transfer to treasury address' inside the callback function
3. The coinFlip function now also accept callbackGasLimit and requestConfirmation as params => For testing purposes

## V3
Deployed address: 0xEE30782897b838c187e00B5156F773c5189C02EA

We've tried to move all heavy processes outside the callback function. In this version the callback function only does writing SC state 
Changes
1. We've moved all transfer processes outside the callback function. 'Claiming reward' action by user will also send corresponding amount to our treasury

## Others
[Subscription page](https://vrf.chain.link/fuji/188)
