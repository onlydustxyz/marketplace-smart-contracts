%lang starknet

@contract_interface
namespace IProject {
    func new_contribution(
        contribution_hash, assignment_strategy_hash, calldata_len: felt, calldata: felt*
    ) -> (contract: felt) {
        // lead_contributor_only
    }

    func add_lead_contributor(contributor_account) {
        // admin_only
    }
    func remove_lead_contributor(contributor_account) {
        // admin_only
    }
    func add_member(contributor_account) {
        // lead_contributor_only
    }
    func remove_member(contributor_account) {
        // lead_contributor_only
    }
}
