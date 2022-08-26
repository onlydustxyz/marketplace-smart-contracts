%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin

from onlydust.marketplace.core.contributions.library import (
    contributions,
    Status,
    Role,
    past_contributions_,
    ContributionId,
)
from onlydust.marketplace.test.libraries.contributions import assert_contribution_that

const ADMIN = 'admin'
const FEEDER = 'feeder'
const REGISTRY = 'registry'
const PROJECT_ID = 'MyProject'
const ID1 = 1000000 * PROJECT_ID + 1
const ID2 = 1000000 * PROJECT_ID + 2

@view
func test_new_contribution_can_be_added{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    alloc_locals

    fixture.initialize()

    %{ stop_prank = start_prank(ids.FEEDER) %}
    let (local contribution1) = contributions.new_contribution(1000000 * PROJECT_ID +1, PROJECT_ID, 0, 'validator')
    let (contribution2) = contributions.new_contribution(1000000 * PROJECT_ID + 2, PROJECT_ID, 0, 'validator')
    %{ stop_prank() %}

    let (count, contribs) = contributions.all_contributions()

    assert 2 = count

    let contribution = contribs[0]
    with contribution:
        assert_contribution_that.id_is(contribution1.id)
        assert_contribution_that.project_id_is(contribution1.project_id)
        assert_contribution_that.status_is(Status.OPEN)
    end

    let contribution = contribs[1]
    with contribution:
        assert_contribution_that.id_is(contribution2.id)
        assert_contribution_that.project_id_is(contribution2.project_id)
        assert_contribution_that.status_is(Status.OPEN)
    end

    %{ expect_events(
        {"name": "ContributionCreated", "data": {"contribution_id": 1, "project_id": ids.PROJECT_ID,  "issue_number": 1, "gate": 0}},
        {"name": "ContributionCreated", "data": {"contribution_id": 2, "project_id": ids.PROJECT_ID,  "issue_number": 2, "gate": 0}},
    )%}
    return ()
end

@view
func test_same_contribution_cannot_be_added_twice{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    alloc_locals

    fixture.initialize()

    %{ 
        stop_prank = start_prank(ids.FEEDER)
        expect_revert(error_message="Contributions: Contribution already exist")
    %}
    let (local contribution1) = contributions.new_contribution(ID1, PROJECT_ID, 0, 'validator')
    let (contribution2) = contributions.new_contribution(ID1, PROJECT_ID, 0, 'validator')
    %{ stop_prank() %}

    return ()
end


@view
func test_feeder_can_assign_contribution_to_contributor{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    let contribution_id = ContributionId(1)
    let contributor_id = Uint256(1, 0)

    %{ stop_prank = start_prank(ids.FEEDER) %}
    let (contribution) = contributions.new_contribution(
        1000000 * PROJECT_ID + 1, PROJECT_ID, 0, 'validator'
    )
    contributions.assign_contributor_to_contribution(contribution_id, contributor_id)
    %{ stop_prank() %}

    let (contribution) = contributions.contribution(contribution_id)
    with contribution:
        assert_contribution_that.status_is(Status.ASSIGNED)
        assert_contribution_that.contributor_is(contributor_id)
    end

    %{ expect_events(
        {"name": "ContributionCreated", "data": {"contribution_id": 1, "project_id": ids.PROJECT_ID,  "issue_number": 1, "gate": 0}},
        {"name": "ContributionAssigned", "data": {"contribution_id": 1, "contributor_id": {"low": 1, "high": 0}}},
    )%}
    return ()
end

@view
func test_anyone_cannot_assign_contribution_to_contributor{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    let contribution_id = ContributionId(1)
    let contributor_id = Uint256(1, 0)

    %{ stop_prank = start_prank(ids.FEEDER) %}
    let (_) = contributions.new_contribution(ID1, PROJECT_ID, 0, 'validator')
    %{
        stop_prank() 
        expect_revert(error_message="Contributions: FEEDER role required")
    %}
    contributions.assign_contributor_to_contribution(contribution_id, contributor_id)

    return ()
end

@view
func test_cannot_assign_non_existent_contribution{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    let contribution_id = ContributionId(1)
    let contributor_id = Uint256(1, 0)

    %{
        stop_prank = start_prank(ids.FEEDER) 
        expect_revert(error_message="Contributions: Contribution does not exist")
    %}
    contributions.assign_contributor_to_contribution(contribution_id, contributor_id)
    %{ stop_prank() %}

    return ()
end

@view
func test_cannot_assign_twice_a_contribution{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    let contribution_id = ContributionId(1)
    let contributor_id = Uint256(1, 0)

    %{ stop_prank = start_prank(ids.FEEDER) %}
    let (_) = contributions.new_contribution(ID1, PROJECT_ID, 0, 'validator')
    contributions.assign_contributor_to_contribution(contribution_id, contributor_id)
    %{ expect_revert(error_message="Contributions: Contribution is not OPEN") %}
    contributions.assign_contributor_to_contribution(contribution_id, contributor_id)
    %{ stop_prank() %}

    return ()
end

@view
func test_cannot_assign_contribution_to_non_eligible_contributor{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    let contribution_id = ContributionId(1)
    let contributor_id = Uint256(1, 0)

    %{ stop_prank = start_prank(ids.FEEDER) %}
    let (_) = contributions.new_contribution(ID1, PROJECT_ID, 3, 'validator')
    %{ expect_revert(error_message="Contributions: Contributor is not eligible") %}
    contributions.assign_contributor_to_contribution(contribution_id, contributor_id)
    %{ stop_prank() %}

    return ()
end

@view
func test_can_assign_gated_contribution_eligible_contributor{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    let contribution_id = ContributionId(1)
    let gated_contribution_id = ContributionId(2)
    let contributor_id = Uint256(1, 0)

    %{ stop_prank = start_prank(ids.FEEDER) %}
    # Create a non-gated contribution
    let (_) = contributions.new_contribution(ID1, PROJECT_ID, 0, 'validator')

    # Create a gated contribution
    let (_) = contributions.new_contribution(ID2, PROJECT_ID, 1, 'validator')

    # Assign and validate the non-gated contribution
    contributions.assign_contributor_to_contribution(contribution_id, contributor_id)
    contributions.validate_contribution(contribution_id)

    # Assign and validate the gated contribution
    contributions.assign_contributor_to_contribution(gated_contribution_id, contributor_id)
    contributions.validate_contribution(gated_contribution_id)
    %{ stop_prank() %}

    let (past_contributions) = contributions.past_contributions(contributor_id)
    assert 2 = past_contributions

    return ()
end

@view
func test_contribution_creation_with_invalid_project_id_is_reverted{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    %{
        stop_prank = start_prank(ids.FEEDER)
        expect_revert(error_message="Contributions: Invalid project ID")
    %}
    let (_) = contributions.new_contribution(ID1, 0, 0, 'validator')
    %{ stop_prank() %}

    return ()
end

@view
func test_contribution_creation_with_invalid_contribution_count_is_reverted{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    %{
        stop_prank = start_prank(ids.FEEDER)
        expect_revert(error_message="Contributions: Invalid contribution count required")
    %}
    let (_) = contributions.new_contribution(ID1, PROJECT_ID, -1, 'validator')
    %{ stop_prank() %}

    return ()
end

@view
func test_anyone_cannot_add_contribution{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    %{ expect_revert(error_message="Contributions: FEEDER role required") %}
    let (_) = contributions.new_contribution(ID1, PROJECT_ID, 0, 'validator')

    return ()
end

@view
func test_feeder_can_unassign_contribution_from_contributor{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    let contribution_id = ContributionId(1)
    let contributor_id = Uint256(1, 0)

    %{ stop_prank = start_prank(ids.FEEDER) %}
    let (_) = contributions.new_contribution(1000000 * PROJECT_ID + 1, PROJECT_ID, 0, 'validator')
    contributions.assign_contributor_to_contribution(contribution_id, contributor_id)
    contributions.unassign_contributor_from_contribution(contribution_id)
    %{ stop_prank() %}

    let (contribution) = contributions.contribution(contribution_id)
    with contribution:
        assert_contribution_that.status_is(Status.OPEN)
        assert_contribution_that.contributor_is(Uint256(0, 0))
    end

    %{ expect_events(
        {"name": "ContributionCreated", "data": {"contribution_id": 1, "project_id": ids.PROJECT_ID, "issue_number": 1, "gate": 0}},
        {"name": "ContributionAssigned", "data": {"contribution_id": 1, "contributor_id": {"low": 1, "high": 0}}},
        {"name": "ContributionUnassigned", "data": {"contribution_id": 1}},
    )%}

    return ()
end

@view
func test_anyone_cannot_unassign_contribution_from_contributor{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    let contribution_id = ContributionId(1)
    let contributor_id = Uint256(1, 0)

    %{ stop_prank = start_prank(ids.FEEDER) %}
    let (_) = contributions.new_contribution(ID1, PROJECT_ID, 0, 'validator')
    contributions.assign_contributor_to_contribution(contribution_id, contributor_id)
    %{
        stop_prank() 
        expect_revert(error_message="Contributions: FEEDER role required")
    %}
    contributions.unassign_contributor_from_contribution(contribution_id)

    return ()
end

@view
func test_cannot_unassign_from_non_existent_contribution{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    let contribution_id = ContributionId(1)
    let contributor_id = Uint256(1, 0)

    %{
        stop_prank = start_prank(ids.FEEDER) 
        expect_revert(error_message="Contributions: Contribution does not exist")
    %}
    contributions.unassign_contributor_from_contribution(contribution_id)
    %{ stop_prank() %}

    return ()
end

@view
func test_cannot_unassign_contribution_if_not_assigned{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    let contribution_id = ContributionId(1)

    %{ stop_prank = start_prank(ids.FEEDER) %}
    let (_) = contributions.new_contribution(ID1, PROJECT_ID, 0, 'validator')
    %{ expect_revert(error_message="Contributions: Contribution is not ASSIGNED") %}
    contributions.unassign_contributor_from_contribution(contribution_id)
    %{ stop_prank() %}

    return ()
end

@view
func test_feeder_can_validate_assigned_contribution{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    let contribution_id = ContributionId(1)
    let contributor_id = Uint256(1, 0)

    %{ stop_prank = start_prank(ids.FEEDER) %}
    let (_) = contributions.new_contribution(ID1, PROJECT_ID, 0, 'validator')
    contributions.assign_contributor_to_contribution(contribution_id, contributor_id)
    contributions.validate_contribution(contribution_id)
    %{ stop_prank() %}

    let (contribution) = contributions.contribution(contribution_id)
    with contribution:
        assert_contribution_that.status_is(Status.COMPLETED)
    end

    %{ expect_events(
        {"name": "ContributionCreated", "data": {"contribution_id": 1, "project_id": ids.PROJECT_ID,  "issue_number": 1, "gate": 0}},
        {"name": "ContributionAssigned", "data": {"contribution_id": 1, "contributor_id": {"low": 1, "high": 0}}},
        {"name": "ContributionValidated", "data": {"contribution_id": 1}},
    )%}

    return ()
end

@view
func test_anyone_cannot_validate_contribution{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    let contribution_id = ContributionId(1)
    let contributor_id = Uint256(1, 0)

    %{ stop_prank = start_prank(ids.FEEDER) %}
    let (_) = contributions.new_contribution(ID1, PROJECT_ID, 0, 'validator')
    contributions.assign_contributor_to_contribution(contribution_id, contributor_id)
    %{
        stop_prank() 
        expect_revert(error_message="Contributions: FEEDER role required")
    %}
    contributions.validate_contribution(contribution_id)

    return ()
end

@view
func test_cannot_validate_non_existent_contribution{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    let contribution_id = ContributionId(1)

    %{
        stop_prank = start_prank(ids.FEEDER) 
        expect_revert(error_message="Contributions: Contribution does not exist")
    %}
    contributions.validate_contribution(contribution_id)
    %{ stop_prank() %}

    return ()
end

@view
func test_cannot_validate_contribution_if_not_assigned{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    let contribution_id = ContributionId(1)

    %{ stop_prank = start_prank(ids.FEEDER) %}
    let (_) = contributions.new_contribution(ID1, PROJECT_ID, 0, 'validator')
    %{ expect_revert(error_message="Contributions: Contribution is not ASSIGNED") %}
    contributions.validate_contribution(contribution_id)
    %{ stop_prank() %}

    return ()
end

@view
func test_feeder_can_modify_contribution_count_required{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    let contribution_id = ContributionId(1)
    let contributor_id = Uint256(1, 0)
    let validator_account = 'validator'

    %{ stop_prank = start_prank(ids.FEEDER) %}
    let (_) = contributions.new_contribution(ID1, PROJECT_ID, 0, validator_account)
    contributions.modify_contribution_count_required(contribution_id, 3)
    %{ stop_prank() %}

    let (contribution) = contributions.contribution(contribution_id)
    with contribution:
        assert_contribution_that.gate_is(3)
    end

    %{ expect_events(
        {"name": "ContributionCreated", "data": {"contribution_id": 1, "project_id": ids.PROJECT_ID,  "issue_number": 1, "gate": 0}},
        {"name": "ContributionGateChanged", "data": {"contribution_id": 1, "gate": 3}},
    )%}

    return ()
end

@view
func test_anyone_cannot_modify_contribution_count_required{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    let contribution_id = ContributionId(1)
    let contributor_id = Uint256(1, 0)
    let validator_account = 'validator'

    %{ stop_prank = start_prank(ids.FEEDER) %}
    let (_) = contributions.new_contribution(ID1, PROJECT_ID, 0, 'validator')
    %{ 
        stop_prank ()
        expect_revert(error_message="Contributions: FEEDER role require")
    %}
    contributions.modify_contribution_count_required(contribution_id, 3)

    return ()
end

@view
func test_admin_cannot_revoke_himself{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    %{
        stop_prank = start_prank(ids.ADMIN)
        expect_revert(error_message="Contributions: Cannot self renounce to ADMIN role")
    %}
    contributions.revoke_admin_role(ADMIN)

    %{ stop_prank() %}

    return ()
end

@view
func test_admin_can_transfer_ownership{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    const NEW_ADMIN = 'new_admin'

    %{ stop_prank = start_prank(ids.ADMIN) %}
    contributions.grant_admin_role(NEW_ADMIN)
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.NEW_ADMIN) %}
    contributions.revoke_admin_role(ADMIN)
    %{
        stop_prank() 
        expect_events(
            {"name": "RoleGranted", "data": [ids.Role.ADMIN, ids.NEW_ADMIN, ids.ADMIN]},
            {"name": "RoleRevoked", "data": [ids.Role.ADMIN, ids.ADMIN, ids.NEW_ADMIN]}
        )
    %}

    return ()
end

@view
func test_anyone_cannot_grant_role{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    %{ expect_revert(error_message="AccessControl: caller is missing role 0") %}
    contributions.grant_admin_role(FEEDER)

    return ()
end

@view
func test_anyone_cannot_revoke_role{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()

    %{ expect_revert(error_message="AccessControl: caller is missing role 0") %}
    contributions.revoke_admin_role(ADMIN)

    return ()
end

@view
func test_admin_can_grant_and_revoke_roles{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    alloc_locals
    fixture.initialize()

    const RANDOM_ADDRESS = 'rand'

    %{ stop_prank = start_prank(ids.ADMIN) %}
    contributions.grant_feeder_role(RANDOM_ADDRESS)
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.RANDOM_ADDRESS) %}
    let (local contribution) = contributions.new_contribution(ID1, PROJECT_ID, 0, 'validator')
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.ADMIN) %}
    contributions.revoke_feeder_role(RANDOM_ADDRESS)
    %{
        stop_prank() 
        expect_events(
            {"name": "RoleGranted", "data": [ids.Role.FEEDER, ids.RANDOM_ADDRESS, ids.ADMIN]},
            {"name": "RoleRevoked", "data": [ids.Role.FEEDER, ids.RANDOM_ADDRESS, ids.ADMIN]}
        )
    %}

    %{
        stop_prank = start_prank(ids.RANDOM_ADDRESS) 
        expect_revert(error_message='Contributions: FEEDER role required')
    %}
    contributions.new_contribution(ID1, PROJECT_ID, 0, 'validator')
    %{ stop_prank() %}

    return ()
end

@view
func test_anyone_can_get_past_contributions_count{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    fixture.initialize()
    let contributor_id = Uint256('greg', '@onlydust')
    fixture.validate_two_contributions(contributor_id)

    let (past_contribution_count) = contributions.past_contributions(contributor_id)
    assert 2 = past_contribution_count

    return ()
end

@view
func test_anyone_can_list_open_contributions{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    alloc_locals
    fixture.initialize()

    %{ stop_prank = start_prank(ids.FEEDER) %}
    let contribution1_id = ContributionId(1)
    let (contribution1) = contributions.new_contribution(
        ID1, PROJECT_ID, 0, 'validator'
    )
    contributions.assign_contributor_to_contribution(contribution1_id, Uint256(1, 0))

    let contribution2_id = ContributionId(2)
    let (local contribution2) = contributions.new_contribution(
        ID2, PROJECT_ID, 0, 'validator'
    )
    %{ stop_prank() %}

    let (contribs_len, contribs) = contributions.all_open_contributions()
    assert 1 = contribs_len
    assert contribution2 = contribs[0]

    return ()
end

@view
func test_anyone_can_list_assigned_contributions{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    alloc_locals
    fixture.initialize()

    let contributor_id = Uint256(1, 0)

    %{ stop_prank = start_prank(ids.FEEDER) %}
    let contribution1_id = ContributionId(1)
    let (contribution1) = contributions.new_contribution(
        ID1, PROJECT_ID, 0, 'validator'
    )
    contributions.assign_contributor_to_contribution(contribution1_id, contributor_id)

    let contribution2_id = ContributionId(2)
    let (local contribution2) = contributions.new_contribution(
        ID2, PROJECT_ID, 0, 'validator'
    )
    %{ stop_prank() %}

    let (contribs_len, contribs) = contributions.assigned_contributions(contributor_id)
    assert 1 = contribs_len
    let contribution = contribs[0]
    with contribution:
        assert_contribution_that.id_is(contribution1_id)
        assert_contribution_that.project_id_is(PROJECT_ID)
        assert_contribution_that.status_is(Status.ASSIGNED)
        assert_contribution_that.contributor_is(contributor_id)
    end

    return ()
end

@view
func test_anyone_can_list_contributions_eligible_to_contributor{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    alloc_locals
    fixture.initialize()

    let contributor_id = Uint256('greg', '@onlydust')

    fixture.validate_two_contributions(contributor_id)

    # Create different contributions

    %{ stop_prank = start_prank(ids.FEEDER) %}
    let contribution_id = ContributionId(3)  # 'open non-gated'
    let (contribution1) = contributions.new_contribution(
        1000000 * 'OnlyDust' + 1, 'OnlyDust', 0, 'validator'
    )

    let contribution_id = ContributionId(4)  # 'assigned non-gated'
    let (local contribution2) = contributions.new_contribution(
        1000000 * 'Briq' + 1, 'Briq', 0, 'validator'
    )
    contributions.assign_contributor_to_contribution(contribution_id, Uint256(1, 0))

    let contribution_id = ContributionId(5)  # 'open gated'
    let (local contribution3) = contributions.new_contribution(
        1000000 * 'Briq' + 2, 'Briq', 1, 'validator'
    )

    let contribution_id = ContributionId(6)  # 'open gated too_high'
    let (local contribution5) = contributions.new_contribution(
        1000000 * 'Briq' + 3, 'Briq', 3, 'validator'
    )

    %{ stop_prank() %}

    let (contribs_len, contribs) = contributions.eligible_contributions(contributor_id)
    assert 5 = contribs_len

    let contribution = contribs[0]
    with contribution:
        assert_contribution_that.id_is(ContributionId(1))
        assert_contribution_that.project_id_is('Random')
        assert_contribution_that.contributor_is(contributor_id)
    end

    let contribution = contribs[2]
    with contribution:
        assert_contribution_that.id_is(ContributionId(3))
        assert_contribution_that.project_id_is('OnlyDust')
        assert_contribution_that.contributor_is(Uint256(0, 0))
    end

    return ()
end

namespace fixture:
    func initialize{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
        contributions.initialize(ADMIN)
        %{ stop_prank = start_prank(ids.ADMIN) %}
        contributions.grant_feeder_role(FEEDER)
        %{ stop_prank() %}
        return ()
    end

    func validate_two_contributions{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
    }(contributor_id : Uint256):
        let contribution_id = ContributionId(1)
        let gated_contribution_id = ContributionId(2)

        %{ stop_prank = start_prank(ids.FEEDER) %}
        # Create a non-gated contribution
        let (contribution) = contributions.new_contribution(
            1000000 * 'Random' + 1, 'Random', 0, 'validator'
        )

        # Create a gated contribution
        let (contribution) = contributions.new_contribution(
            1000000 * 'Random' + 2, 'Random', 1, 'validator'
        )

        # Assign and validate the non-gated contribution
        contributions.assign_contributor_to_contribution(contribution_id, contributor_id)
        contributions.validate_contribution(contribution_id)

        # Assign and validate the gated contribution
        contributions.assign_contributor_to_contribution(gated_contribution_id, contributor_id)
        contributions.validate_contribution(gated_contribution_id)
        %{ stop_prank() %}

        let (past_contributions) = contributions.past_contributions(contributor_id)
        assert 2 = past_contributions

        return ()
    end
end
