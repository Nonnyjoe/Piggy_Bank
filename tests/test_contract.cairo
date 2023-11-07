use core::{traits::Into, debug::PrintTrait};
// use array::ArrayTrait;
// use result::ResultTrait;
// use option::OptionTrait;
use traits::TryInto;
use starknet::{ContractAddress, get_contract_address};
use starknet::Felt252TryIntoContractAddress;
use piggy_bank::piggy_bank::{IERC20Dispatcher, IERC20DispatcherTrait, };
use piggy_bank::piggy_bank::piggyBank::targetOption;
use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank, start_warp, stop_warp, env::var};
use piggy_bank::piggy_bank::piggyBankTraitDispatcher;
use piggy_bank::piggy_bank::piggyBankTraitDispatcherTrait;

fn deploy_contract(name: felt252, owner: ContractAddress, token: ContractAddress, manager: ContractAddress, target: u8, targetDetails: u128) -> ContractAddress {
    let contract = declare(name);
    let mut calldata = ArrayTrait::new();
    owner.serialize(ref calldata);
    // target.serialize(ref calldata);
    token.serialize(ref calldata);
    manager.serialize(ref calldata);
    target.serialize(ref calldata);
    targetDetails.serialize(ref calldata);

    // Precalculate the address to obtain the contract address before the constructor call (deploy) itself
    let contract_address = contract.precalculate_address(@calldata);

    // Change the caller address to 123 before the call to contract.deploy
    start_prank(contract_address, owner.try_into().unwrap());
    let deployedContract = contract.deploy(@calldata).unwrap();
    stop_prank(contract_address);

    deployedContract
}


fn get_important_addresses() ->(ContractAddress, ContractAddress, ContractAddress,) {
    let caller: ContractAddress = 0x048242eca329a05af1909fa79cb1f9a4275ff89b987d405ec7de08f73b85588f.try_into().unwrap();
    let EthToken: ContractAddress = 0x049D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7.try_into().unwrap();
    let this: ContractAddress = get_contract_address();
    return (caller, EthToken, this);
}


#[test]
fn test_initial_balance() {
    let (caller, EthToken, this) = get_important_addresses();
    let targetSavings = 10_000000000000000000;
    let contract_address = deploy_contract('piggyBank', caller, EthToken, this, 1, targetSavings);
    let piggy_dispatcher = piggyBankTraitDispatcher { contract_address }; 
    let initial_balance: u128 = piggy_dispatcher.get_balance();
   
    assert(initial_balance == 0, 'Invalid balance');
}


#[test]
fn test_expected_owner() {
    let (caller, EthToken, this) = get_important_addresses();
    let targetSavings = 10_000000000000000000;
    let contract_address = deploy_contract('piggyBank', caller, EthToken, this, 1, targetSavings);
    let piggy_dispatcher = piggyBankTraitDispatcher { contract_address };
    let owner: ContractAddress = piggy_dispatcher.get_owner();

    assert(owner == caller, 'Unexpected owner');
}


#[test]
#[fork("GoerliFork")]
fn test_deposit_into_Account() {
    let (caller, EthToken, this) = get_important_addresses();
    let targetSavings = 10_000000000000000000;
    let contract_address = deploy_contract('piggyBank', caller, EthToken, this, 1, targetSavings);
    let piggy_dispatcher = piggyBankTraitDispatcher { contract_address };
    let eth_dispatcher = IERC20Dispatcher{ contract_address: EthToken};
    let depositAmount: u128 = 1000000000000000000;

    start_prank(EthToken, caller);
    eth_dispatcher.approve(contract_address, depositAmount.into());
    stop_prank(EthToken);

    start_prank(contract_address, caller);
    piggy_dispatcher.deposit(depositAmount);
    stop_prank(contract_address);

    let newBalance: u128 = eth_dispatcher.balanceOf(contract_address).try_into().unwrap();
    let currentBalance = piggy_dispatcher.get_balance();
    assert(currentBalance == depositAmount, 'WRONG CONTRACT BALANCE');
    assert(newBalance == depositAmount, 'CONTRACT BALANCE SHOULD TALLY');
}


#[test]
#[fork("GoerliFork")]
fn test_withdraw_without_meeting_target_amount() {
    let (caller, EthToken, this) = get_important_addresses();
    let targetSavings = 10_000000000000000000;
    let contract_address = deploy_contract('piggyBank', caller, EthToken, this, 1, targetSavings);
    let piggy_dispatcher = piggyBankTraitDispatcher { contract_address };
    let eth_dispatcher = IERC20Dispatcher{ contract_address: EthToken};
    let depositAmount: u128 = 1000000000000000000;

    start_prank(EthToken, caller);
    eth_dispatcher.approve(contract_address, depositAmount.into());
    stop_prank(EthToken);

    start_prank(contract_address, caller);
    piggy_dispatcher.deposit(depositAmount);
    let managerBlanceBefore = eth_dispatcher.balanceOf(this);
    piggy_dispatcher.withdraw(depositAmount);
    stop_prank(contract_address);

    let managerBlance = eth_dispatcher.balanceOf(this);
    let expectedManagerBlance = (depositAmount * 10) / 100;
    let piggyBalanceAfter = piggy_dispatcher.get_balance();
    let expectedPiggyBalanceAfter = 0;
    
    assert(managerBlance == expectedManagerBlance.into(), 'WRONG MANAGER BALANCE');
    assert(managerBlance != managerBlanceBefore, 'MANAGER BALANCE DOES NOT TALLY');
    assert(piggyBalanceAfter == expectedPiggyBalanceAfter, 'WRONG PIGGY BALANCE CALC');
}


#[test]
#[fork("GoerliFork")]
fn test_withdraw_after_meeting_target_amount() {
    let (caller, EthToken, this) = get_important_addresses();
    let targetSavings = 10_000000000000000000;
    let contract_address = deploy_contract('piggyBank', caller, EthToken, this, 1, targetSavings);
    let piggy_dispatcher = piggyBankTraitDispatcher { contract_address };
    let eth_dispatcher = IERC20Dispatcher{ contract_address: EthToken};
    let depositAmount: u128 = 10000000000000000000;

    start_prank(EthToken, caller);
    eth_dispatcher.approve(contract_address, depositAmount.into());
    stop_prank(EthToken);

    start_prank(contract_address, caller);
    piggy_dispatcher.deposit(depositAmount);

    let managerBlanceBefore = eth_dispatcher.balanceOf(this);

    piggy_dispatcher.withdraw(depositAmount);
    stop_prank(contract_address);

    let managerBlance = eth_dispatcher.balanceOf(this);
    let expectedManagerBlance = 0;
    let piggyBalanceAfter = piggy_dispatcher.get_balance();
    let expectedPiggyBalanceAfter = 0;
    
    assert(managerBlance == expectedManagerBlance.into(), 'WRONG MANAGER BALANCE');
    assert(managerBlance == managerBlanceBefore, 'MANAGER BALANCE DOES NOT TALLY');
    assert(piggyBalanceAfter == expectedPiggyBalanceAfter, 'WRONG PIGGY BALANCE CALC');
}


#[test]
#[fork("GoerliFork")]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_UnAuthorized_user_withdrawal_Attempt() {
    let (caller, EthToken, this) = get_important_addresses();
    let targetSavings = 10_000000000000000000;
    let contract_address = deploy_contract('piggyBank', caller, EthToken, this, 1, targetSavings);
    let piggy_dispatcher = piggyBankTraitDispatcher { contract_address };
    let eth_dispatcher = IERC20Dispatcher{ contract_address: EthToken};
    let depositAmount: u128 = 10000000000000000000;
    let unAuthorizedUser: ContractAddress = 123.try_into().unwrap();

    start_prank(EthToken, caller);
    eth_dispatcher.approve(contract_address, depositAmount.into());
    stop_prank(EthToken);

    start_prank(contract_address, caller);
    piggy_dispatcher.deposit(depositAmount);
    stop_prank(contract_address);

    let managerBlanceBefore = eth_dispatcher.balanceOf(this);
    let UUBlanceBefore = eth_dispatcher.balanceOf(unAuthorizedUser);
    let piggyBalanceBefore = piggy_dispatcher.get_balance();

    start_prank(contract_address, unAuthorizedUser);
    piggy_dispatcher.withdraw(depositAmount);
    stop_prank(contract_address);

    let managerBlance = eth_dispatcher.balanceOf(this);
    let UUBlanceAfter = eth_dispatcher.balanceOf(unAuthorizedUser);
    let piggyBalanceAfter = piggy_dispatcher.get_balance();

    assert(UUBlanceBefore == UUBlanceAfter, 'UNAUTHORIZED USER WITHDRAWAL');
    assert(piggyBalanceBefore == piggyBalanceAfter, 'UNAUTHORIZED LOSS OF FUNDS');
}


#[test]
#[fork("GoerliFork")]
fn test_withdraw_after_meeting_target_time() {
    let (caller, EthToken, this) = get_important_addresses();
    let targetTime = 1000;
    let contract_address = deploy_contract('piggyBank', caller, EthToken, this, 0, targetTime);
    let piggy_dispatcher = piggyBankTraitDispatcher { contract_address };
    let eth_dispatcher = IERC20Dispatcher{ contract_address: EthToken};
    let depositAmount: u128 = 10000000000000000000;
    let unAuthorizedUser: ContractAddress = 123.try_into().unwrap();

    start_prank(EthToken, caller);
    eth_dispatcher.approve(contract_address, depositAmount.into());
    stop_prank(EthToken);

    start_prank(contract_address, caller);
    start_warp(contract_address, 100);
    piggy_dispatcher.deposit(depositAmount);
    let managerBlanceBefore = eth_dispatcher.balanceOf(this);

    start_warp(contract_address, 2100);
    piggy_dispatcher.withdraw(depositAmount);
    stop_prank(contract_address);

    let managerBlance = eth_dispatcher.balanceOf(this);
    let expectedManagerBlance = 0;
    let piggyBalanceAfter = piggy_dispatcher.get_balance();
    let expectedPiggyBalanceAfter = 0;
    
    assert(managerBlance == expectedManagerBlance.into(), 'WRONG MANAGER BALANCE');
    assert(managerBlance == managerBlanceBefore, 'MANAGER BALANCE DOES NOT TALLY');
    assert(piggyBalanceAfter == expectedPiggyBalanceAfter, 'WRONG PIGGY BALANCE CALC');
}

#[test]
#[fork("GoerliFork")]
fn test_withdraw_without_meeting_target_time() {
    let (caller, EthToken, this) = get_important_addresses();
    let targetTime = 2000170827;
    let contract_address = deploy_contract('piggyBank', caller, EthToken, this, 0, targetTime);
    let piggy_dispatcher = piggyBankTraitDispatcher { contract_address };
    let eth_dispatcher = IERC20Dispatcher{ contract_address: EthToken};
    let depositAmount: u128 = 10000000000000000000;
    let unAuthorizedUser: ContractAddress = 123.try_into().unwrap();

    start_prank(EthToken, caller);
    eth_dispatcher.approve(contract_address, depositAmount.into());
    stop_prank(EthToken);

    start_prank(contract_address, caller);
    piggy_dispatcher.deposit(depositAmount);
    let managerBlanceBefore = eth_dispatcher.balanceOf(this);
    piggy_dispatcher.withdraw(depositAmount);
    stop_prank(contract_address);

    let managerBlance = eth_dispatcher.balanceOf(this);
    let expectedManagerBlance = (depositAmount * 10) / 100;
    let piggyBalanceAfter = piggy_dispatcher.get_balance();
    let expectedPiggyBalanceAfter = 0;
    
    assert(managerBlance == expectedManagerBlance.into(), 'WRONG MANAGER BALANCE');
    assert(managerBlance != managerBlanceBefore, 'MANAGER BALANCE DOES NOT TALLY');
    assert(piggyBalanceAfter == expectedPiggyBalanceAfter, 'WRONG PIGGY BALANCE CALC');
}




