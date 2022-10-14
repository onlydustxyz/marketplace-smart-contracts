%lang starknet

from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin

@storage_var
func assignment_strategy__test__function_calls(function_selector: felt) -> (count: felt) {
}

@storage_var
func assignment_strategy__test__revert_requested(function_selector: felt) -> (
    revert_requested: felt
) {
}

@external
@raw_input
@raw_output
func __default__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    selector: felt, calldata_size: felt, calldata: felt*
) -> (retdata_size: felt, retdata: felt*) {
    // %{ print(f'{hex(ids.selector)}') %} // Uncomment to add more selectors in unit test
    let (count) = assignment_strategy__test__function_calls.read(selector);
    assignment_strategy__test__function_calls.write(selector, count + 1);

    let (revert_requested) = assignment_strategy__test__revert_requested.read(selector);
    with_attr error_message("Revert requested") {
        assert FALSE = revert_requested;
    }

    return (retdata_size=0, retdata=new ());
}

//
// AssignmentStrategyMock functions
//
namespace AssignmentStrategyMock {
    func setup{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> felt {
        internal.register_selectors();
        return internal.declare();
    }

    func class_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> felt {
        return internal.declare();
    }

    func revert_on_call{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        function_name: felt
    ) {
        tempvar selector;
        %{ ids.selector = context.selectors[ids.function_name] %}
        assignment_strategy__test__revert_requested.write(selector, TRUE);
        return ();
    }

    func get_function_call_count{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        function_name
    ) -> felt {
        tempvar selector;
        %{ ids.selector = context.selectors[ids.function_name] %}

        let (count) = assignment_strategy__test__function_calls.read(selector);
        return count;
    }
}

namespace internal {
    func declare{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> felt {
        tempvar test_strategy_hash;
        %{
            if not hasattr(context, 'test_strategy_hash'):
                context.test_strategy_hash = declare("./contracts/onlydust/marketplace/test/libraries/assignment_strategy_mock.cairo", config={"wait_for_acceptance": True}).class_hash
            ids.test_strategy_hash = context.test_strategy_hash
        %}

        return test_strategy_hash;
    }

    func register_selectors() {
        %{ context.selectors = {} %}

        register_selector(
            'initialize', 0x79dc0da7c54b95f10aa182ad0a46400db63156920adb65eca2654c0945a463
        );
        register_selector(
            'assert_can_assign', 0xafebfa3bc187991e56ad073c19677f894a3a5541d8b8151af100e49077f937
        );
        register_selector(
            'on_assigned', 0xf897b8b0d9c032035dd00f05036ece8d0323783ada50f77ac038b5ee28a4f7
        );
        register_selector(
            'assert_can_unassign', 0x24d59f9e6d82d630ed029dc7ad5594e04122af91ac85426ec2c05cfec580997
        );
        register_selector(
            'on_unassigned', 0x85a2edab325660d13eb75ace9a6737467ded8f85473feb457595808fbbfdce
        );
        register_selector(
            'assert_can_validate', 0x335791ca04a8d33572330929a1f5d0ed5ccb04474422093c6ca6cb510ad1bc6
        );
        register_selector(
            'on_validated', 0x8a3674db7fb20b307d4be1223ac3ebe7d05225da47a185d1fffacc26f495c7
        );

        return ();
    }

    func register_selector(function_name, selector) {
        %{ context.selectors[ids.function_name] = ids.selector %}
        return ();
    }
}
