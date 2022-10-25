%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.onlydust.marketplace.core.assignment_strategies.recurring import (
    initialize,
    assert_can_assign,
    on_assigned,
    assert_can_unassign,
    on_unassigned,
    assert_can_validate,
    on_validated,
)

//
// Constants
//
const CONTRIBUTOR_ACCOUNT_ADDRESS = 0x0735dc2018913023a5aa557b6b49013675ac4a35ce524cad94f5202d285678cd;

//
// Tests
//
@external
func test_can_assign_if_enough_slot_left{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    initialize(1);
    Contribution.assign(CONTRIBUTOR_ACCOUNT_ADDRESS);

    return ();
}

namespace Contribution {
    func assign{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        contributor_account_address: felt
    ) {
        assert_can_assign(contributor_account_address);
        on_assigned(contributor_account_address);
        return ();
    }
}
