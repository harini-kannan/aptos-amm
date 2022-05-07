module AMM {
    use Std::Errors;
    use Std::Event;
    use Std::Signer;
    use 0x1::Math;
    use AptosFramework::Coin;

    const PRECISION : u128 = 1000000;

    // initialization constants
    const pool_addr = "0x00000000000000000000000000003333";
    const total_1_init = 10;
    const total_2_init = 5;
    const total_lp_init = 100;
    
    struct PoolData has copy, key, drop, store {
        // token1: Coin;
        // token2: Coin;
        total_token1: u128;
        total_token2: u128;
        total_lp_tokens: u128;
        k: u128;
    }

    struct UserTokens has copy, key, drop, store {
        lp_token_balance: u128;
        token1_balance: u128;
        token2_balance: u128;
    }


    public fun get_balance(addr: address): (u128, u128, u128) acquires UserTokens {
        assert!(exists<UserTokens>(addr));
        let userTokens = *&borrow_global<UserTokens>(addr);
        return (userTokens.token1_balance, userTokens.token2_balance, userTokens.lp_token_balance);
    }

    public fun get_pool_details(): (u128, u128, u128) {
        let pool_tokens = *&borrow_global<PoolData>(pool_addr);
        return (pool_tokens.total_token1, pool_tokens.total_token2, pool_tokens.total_lp_tokens);
    }

    public fun get_withdraw_estimate(amount_lp_tokens: u128): (u128, u128) {
        let pool_tokens = *&borrow_global<PoolData>(pool_addr);
        assert(amount_lp_tokens <= pool_tokens.total_lp_tokens);
        let amount_token1 = Math::div(Math::mul(amount_lp_tokens, pool_tokens.total_token1), pool_tokens.total_lp_tokens);
        let amount_token2 = Math::div(Math::mul(amount_lp_tokens, pool_tokens.total_token2), pool_tokens.total_lp_tokens);
        return (amount_token1, amount_token2);
    }

    public fun faucet(amount_token1: u128, amount_token2: u128, account: signer) {

        (token1_balance, token2_balance, lp_token_balance) = get_balance(address);

        let account_addr = Signer::address_of(&account);
        if (!exists<UserTokens>(account_addr)) {
            let old_user_balance = borrow_global_mut<UserTokens>(account_addr);
            old_user_balance.token1_balance = amount_token1;
            old_user_balance.token2_balance = amount_token2;
        } else {
            move_to(&account, UserTokens {
                token1_balance: Math::sum(token1_balance, amount_token1),
                token2_balance: Math::sum(token2_balance, amount_token2)
            })
        }
    }

    public fun provide(amount_token1: u128, amount_token2: u128) {
        let pool_tokens = *&borrow_global_mut<PoolData>(pool_addr);
        if (total_lp_tokens == 0) {
            lp_tokens = 100 * PRECISION;
        } else {
            lp_tokens1 = Math::div(Math::mul(pool_tokens.total_lp_tokens, amount_token1), pool_tokens.total_token1);
            lp_tokens2 = Math::div(Math::mul(pool_tokens.total_lp_tokens, amount_token2), pool_tokens.total_token2);
            assert(lp_tokens1 == lp_tokens2);
            lp_tokens = lp_tokens1;
        }
       
        move_to(&account, UserTokens {
            token1_balance: Math::sub(token1_balance, amount_token1),
            token2_balance: Math::sub(token2_balance, amount_token2)
        });

        new_token1 = Math::sub(pool_tokens.total_token1, amount_token1);
        new_token2 = Math::sub(pool_tokens.total_token2, amount_token2);

        move_to(pool_addr, PoolData {
            total_token1: new_token1,
            total_token2: new_token2,
            total_lp_tokens: Math::sum(pool_tokens.total_lp_tokens, lp_tokens),
            k: Math::mul(new_token1, new_token2)
        });
        move_to(&account, UserTokens {
            lp_token_balance: Math::sum(lp_token_balance, lp_tokens)
        });
    }

    public fun withdraw(lp_tokens: u128): (u128, u128) {
        let amount = get_withdraw_estimate(lp_tokens);
        let pool_tokens = *&borrow_global_mut<PoolData>(pool_addr);
        move_to(&account, UserTokens {
            lp_token_balance: Math::sub(lp_token_balance, lp_tokens)
        });

        new_token1 = Math::sub(pool_tokens.total_token1, amount[0]),
        new_token2 = Math::sub(pool_tokens.total_token2, amount[1]);
        
        move_to(pool_addr, PoolData {
            total_lp_tokens: Math::sub(pool_tokens.total_lp_tokens, lp_tokens),
            total_token1: new_token1,
            total_token2: new_token2,
            k: Math::mul(new_token1, new_token2)
        })

        move_to(&account, UserTokens {
            token1_balance: Math::add(token1_balance, amount_token1),
            token2_balance: Math::add(token2_balance, amount_token2)
        }); 
    }

    public fun get_equiv_token1_estimate(amount_token2: u128): (u128) {
        let pool_tokens = *&borrow_global<PoolData>(pool_addr);
        return Math::div(Math::mul(pool_tokens.total_token1, amount_token2)), pool_tokens.total_token2);
    }

    public fun get_equiv_token2_estimate(amount_token1: u128): (u128) {
        let pool_tokens = *&borrow_global<PoolData>(pool_addr);
        return Math::div(Math::mul(pool_tokens.total_token2, amount_token1)), pool_tokens.total_token1);
    }

    public fun get_swap_token1_estimate(amount_token1: u128): (u128) {
        let pool_tokens = *&borrow_global<PoolData>(pool_addr);
        u128 token1_after = Math::sum(pool_tokens.total_token1, amount_token1);
        u128 token2_after = Math::div(k, token1_after);
        amount_token2 = Math::sub(pool_tokens.total_token2, token2_after);

        if (amount_token2 == total_token2) {
            amount_token2 = amount_token2 - 1;
        }
    }

    public fun get_swap_token1_estimate_given_token2(amount_token2: u128): (u128) {
        let pool_tokens = *&borrow_global<PoolData>(pool_addr);
        assert(amount_token2 < pool_tokens.total_token2);
        u128 token2_after = Math::sub(pool_tokens.total_token2, amount_token2);
        u128 token1_after = Math::div(k, token2_after);
        amount_token1 = Math::sub(token1_after, pool_tokens.total_token1);
        return amount_token1;
    }

    public fun get_swap_token2_estimate(amount_token2: u128): (u128) {
        let pool_tokens = *&borrow_global<PoolData>(pool_addr);
        u128 token2_after = Math::sum(pool_tokens.total_token2, amount_token2);
        u128 token1_after = Math::div(k, token2_after);
        amount_token1 = Math::sub(pool_tokens.total_token1, token1_after);

        if (amount_token1 == pool_tokens.total_token1) {
            amount_token1 = amount_token1 - 1;
        }
    }

    public fun get_swap_token2_estimate_given_token1(amount_token1: u128): (u128) {
        let pool_tokens = *&borrow_global<PoolData>(pool_addr);
        assert(amount_token1 < pool_tokens.total_token1);
        u128 token1_after = Math::sub(pool_tokens.total_token1, amount_token1);
        u128 token2_after = Math::div(k, token1_after);
        amount_token2 = Math::sub(token2_after, pool_tokens.total_token2);
        return amount_token2;
    }

    public fun swap_token1(addr: address, amount_token1: u128): (u128) {
        let pool_tokens = *&borrow_global_mut<PoolData>(pool_addr);
        let (bal_t1, bal_t2, bal_lp) = get_balance(address)
        amount_token2 = get_swap_token1_estimate(amount_token1);
        move_to(&account, UserTokens {
            token1_balance: Math::sub(bal_t1, amount_token1)
        });
        move_to(pool_addr, PoolData {
            total_token1: Math::add(pool_tokens.total_token1, amount_token1),
            total_token2: Math::sub(pool_tokens.total_token2, amount_token2)
        });
        move_to(&account, UserTokens {
            token2_balance: Math::add(bal_t2, amount_token2)
        });
        return Math::add(bal_t2, amount_token2);
    }

    public fun swap_token2(addr: address, amount_token2: u128): (u128) {
        let pool_tokens = *&borrow_global_mut<PoolData>(pool_addr);
        let (bal_t1, bal_t2, bal_lp) = get_balance(address)
        amount_token1 = get_swap_token2_estimate(amount_token1);
        move_to(&account, UserTokens {
            token2_balance: Math::sub(bal_t2, amount_token2)
        });
        move_to(pool_addr, PoolData {
            total_token1: Math::sub(pool_tokens.total_token1, amount_token1), 
            total_token2: Math::add(pool_tokens.total_token2, amount_token2)
        });
        move_to(&account, UserTokens {
            token1_balance: Math::add(bal_t1, amount_token1)
        });
        return Math::add(bal_t1, amount_token1);
    }

    public(script) fun initialize_pool(account: signer) {
        let signer_addr = Signer::address_of(&account);
        const k_init = total_1 * total_2;
        move_to<T>(pool_addr, PoolData {
            // token1: coin1;
            // token2: coin2;
            total_token1: total_1_init,
            total_token2: total_2_init,
            total_lp_tokens: total_lp_init,
            k: k_init
        });
    }

}