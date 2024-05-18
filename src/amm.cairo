#[starknet::contract]
mod AMM {
	use starknet::get_caller_address;
	use starknet::ContractAddress;

	const BALANCE_UPPER_BOUND: u128 = 1073741824; // 2^30 Max amount AMM
	const POOL_UPPER_BOUND: u128 = 1048576; // 2^20 Max amount pool
	const ACCOUNT_UPPER_BOUND: u128 = 104857; // POOL_UPPER_BOUND / 10 Max amount per account

	const TOKEN_A: felt252 = 1;
	const TOKEN_B: felt252 = 2;

	#[storage]
	struct Storage {
		account_balance: LegacyMap::<(ContractAddress, felt252), u128>,
		pool_balance: LegacyMap::<felt252, u128>,
	}

	#[external(v0)]
	#[generate_trait]
	impl IAMMImpl of IMMTrait {

		// Return balance of an account for a token
		fn get_account_balance(self: @ContractState, account: ContractAddress, token: felt252) -> u128 {
			return self.account_balance.read((account, token));
		}

		// Return pool balance for a token
		fn get_pool_balance(self: @ContractState, token: felt252) -> u128 {
			return self.pool_balance.read(token);
		}

		// Set pool balance
		fn set_pool_balance(ref self: ContractState, token: felt252, balance: u128) {
			assert(((BALANCE_UPPER_BOUND - 1) > balance), 'Balance above maximum allowed.');

			self.pool_balance.write(token, balance);
		}

		// Add demo token
		fn add_demo_token(ref self: ContractState, a_amount: u128, b_amount: u128) {
			let account = get_caller_address();

			self.set_account_balance(account, TOKEN_A, a_amount);
			self.set_account_balance(account, TOKEN_B, b_amount);
		}

		// Initialize AMM
		fn init_pool(ref self: ContractState, a_amount: u128, b_amount: u128) {
			let limit_a = (POOL_UPPER_BOUND - 1) > a_amount;
			let limit_b = (POOL_UPPER_BOUND - 1) > b_amount;

			assert((limit_a & limit_b), 'Balance above maximum allowed.');

			self.set_pool_balance(TOKEN_A, a_amount);
			self.set_pool_balance(TOKEN_B, b_amount);
		}

		// Swap
		fn swap(ref self: ContractState, token: felt252, amount: u128) {
			let account = get_caller_address();

			assert((token == TOKEN_A || token == TOKEN_B), 'Unavailable token.');
			assert(((BALANCE_UPPER_BOUND - 1) > amount), 'Balance above maximum allowed');

			let account_balance = self.get_account_balance(account, token);
			assert((account_balance > amount), 'Not enough balance.');

			let opposite = self.get_opposite(token);

			self.execute_swap(account, token, opposite, amount);
		}
	}

	#[generate_trait]
	impl AMMUtilsImpl of AMMUtilsTrait {
		// Set account balance
		fn set_account_balance(ref self: ContractState, account: ContractAddress, token: felt252, amount: u128) {
			let current_balance = self.account_balance.read((account, token));
			let new_balance = current_balance + amount;

			assert(((BALANCE_UPPER_BOUND - 1) > new_balance), 'Balance above maximum allowed.');

			self.account_balance.write((account, token), new_balance);
		}

		// Get opposite token
		fn get_opposite(self: @ContractState, token: felt252) -> felt252 {
			if (token == TOKEN_A) {
				return TOKEN_B;
			} else {
				return TOKEN_A;
			}
		}

		// Execute swap
		fn execute_swap(ref self: ContractState, account: ContractAddress, from: felt252, to: felt252, amount: u128) {
			let from_pool_balance = self.get_pool_balance(from);
			let to_pool_balance = self.get_pool_balance(to);
			let amount_to = (to_pool_balance * amount) / (from_pool_balance + amount);

			self.set_account_balance(account, from, (0 - amount));
			self.set_account_balance(account, to, amount_to);

			self.set_pool_balance(from, (from_pool_balance + amount));
			self.set_pool_balance(to, (to_pool_balance - amount_to));
		}
	}
}
