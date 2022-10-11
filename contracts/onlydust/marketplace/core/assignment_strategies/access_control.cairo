%lang starknet

from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

from contracts.onlydust.marketplace.interfaces.project import IProject

@storage_var
func assignment_strategy_access_control_project_contract_address() -> (
    project_contract_address: felt
) {
}

func initialize{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    project_contract_address
) {
    assignment_strategy_access_control_project_contract_address.write(project_contract_address);
    return ();
}

@external
func can_assign{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    contributor_account
) -> (can_assign: felt) {
    let (caller_address) = get_caller_address();
    let (
        project_contract_address
    ) = assignment_strategy_access_control_project_contract_address.read();

    let (is_project_lead) = IProject.is_lead_contributor(project_contract_address, caller_address);
    if (is_project_lead == TRUE) {
        return (TRUE,);
    }

    if (caller_address != contributor_account) {
        return (FALSE,);
    }

    let (is_member) = IProject.is_member(project_contract_address, caller_address);

    return (is_member,);
}

@external
func can_unassign{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    contributor_account
) -> (can_unassign: felt) {
    let (caller_address) = get_caller_address();
    let (
        project_contract_address
    ) = assignment_strategy_access_control_project_contract_address.read();

    if (caller_address == contributor_account) {
        return (TRUE,);
    }

    let (is_project_lead) = IProject.is_lead_contributor(project_contract_address, caller_address);

    return (is_project_lead,);
}

@external
func can_validate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    contributor_account
) -> (can_validate: felt) {
    let (caller_address) = get_caller_address();
    let (
        project_contract_address
    ) = assignment_strategy_access_control_project_contract_address.read();

    let (is_project_lead) = IProject.is_lead_contributor(project_contract_address, caller_address);

    return (is_project_lead,);
}
