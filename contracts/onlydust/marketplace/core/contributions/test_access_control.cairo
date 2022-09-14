%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from onlydust.marketplace.core.contributions.access_control import access_control, Role

const ADMIN = 'admin';
const LEAD_CONTRIBUTOR_ACCOUNT = 'lead_contributor';
const PROJECT_ID = 'MyProject';
const RANDOM_ADDRESS = 'rand';

@view
func test_admin_cannot_revoke_himself{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    fixture.initialize();

    %{
        stop_prank = start_prank(ids.ADMIN)
        expect_revert(error_message="Contributions: Cannot self renounce to ADMIN role")
    %}
    access_control.revoke_admin_role(ADMIN);

    %{ stop_prank() %}

    return ();
}

@view
func test_admin_can_transfer_ownership{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    fixture.initialize();

    const NEW_ADMIN = 'new_admin';

    %{ stop_prank = start_prank(ids.ADMIN) %}
    access_control.grant_admin_role(NEW_ADMIN);
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.NEW_ADMIN) %}
    access_control.revoke_admin_role(ADMIN);
    %{
        stop_prank() 
        expect_events(
            {"name": "RoleGranted", "data": [ids.Role.ADMIN, ids.NEW_ADMIN, ids.ADMIN]},
            {"name": "RoleRevoked", "data": [ids.Role.ADMIN, ids.ADMIN, ids.NEW_ADMIN]}
        )
    %}

    return ();
}

@view
func test_anyone_cannot_grant_role{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    fixture.initialize();

    %{ expect_revert(error_message="AccessControl: caller is missing role 0") %}
    access_control.grant_admin_role(RANDOM_ADDRESS);

    return ();
}

@view
func test_anyone_cannot_revoke_role{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    fixture.initialize();

    %{ expect_revert(error_message="AccessControl: caller is missing role 0") %}
    access_control.revoke_admin_role(ADMIN);

    return ();
}

@view
func test_admin_can_grant_and_revoke_roles{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    fixture.initialize();

    %{ stop_prank = start_prank(ids.ADMIN) %}
    access_control.grant_lead_contributor_role_for_project(1, RANDOM_ADDRESS);
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.RANDOM_ADDRESS) %}
    access_control.only_lead_contributor(1);
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.ADMIN) %}
    access_control.revoke_lead_contributor_role_for_project(1, RANDOM_ADDRESS);
    %{ stop_prank() %}

    %{
        stop_prank = start_prank(ids.RANDOM_ADDRESS) 
        expect_revert(error_message='Contributions: LEAD_CONTRIBUTOR role required')
    %}

    access_control.only_lead_contributor(1);
    %{
        stop_prank() 
        expect_events(
            {"name": "LeadContributorAdded", "data": [1, ids.RANDOM_ADDRESS]},
            {"name": "LeadContributorRemoved", "data": [1, ids.RANDOM_ADDRESS]}
        )
    %}
    return ();
}

@view
func test_only_admin_can_grant_lead_contributor_role{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    let NEW_LEAD_CONTRIBUTOR_ACCOUNT = 'lead_contributor';

    fixture.initialize();

    %{ stop_prank = start_prank(ids.ADMIN) %}
    access_control.grant_lead_contributor_role_for_project(
        PROJECT_ID, NEW_LEAD_CONTRIBUTOR_ACCOUNT
    );
    %{ stop_prank() %}

    %{ expect_revert(error_message="Contributions: ADMIN role required") %}
    access_control.grant_lead_contributor_role_for_project(
        PROJECT_ID, NEW_LEAD_CONTRIBUTOR_ACCOUNT
    );

    return ();
}

@view
func test_only_admin_can_revoke_lead_contributor_role{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    let NEW_LEAD_CONTRIBUTOR_ACCOUNT = 'lead_contributor';

    fixture.initialize();

    %{ stop_prank = start_prank(ids.ADMIN) %}
    access_control.revoke_lead_contributor_role_for_project(
        PROJECT_ID, NEW_LEAD_CONTRIBUTOR_ACCOUNT
    );
    %{ stop_prank() %}

    %{ expect_revert(error_message="Contributions: ADMIN role required") %}
    access_control.revoke_lead_contributor_role_for_project(
        PROJECT_ID, NEW_LEAD_CONTRIBUTOR_ACCOUNT
    );

    return ();
}

@view
func test_only_lead_contributor_revert_if_no_permission{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    fixture.initialize();

    const NEW_LEAD_CONTRIBUTOR_ACCOUNT = 'lead_contributor';

    %{ stop_prank = start_prank(ids.ADMIN) %}
    access_control.grant_lead_contributor_role_for_project(
        PROJECT_ID, NEW_LEAD_CONTRIBUTOR_ACCOUNT
    );
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.NEW_LEAD_CONTRIBUTOR_ACCOUNT) %}
    access_control.only_lead_contributor(PROJECT_ID);
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.ADMIN) %}
    access_control.revoke_lead_contributor_role_for_project(
        PROJECT_ID, NEW_LEAD_CONTRIBUTOR_ACCOUNT
    );
    %{ stop_prank() %}

    %{
        stop_prank = start_prank(ids.NEW_LEAD_CONTRIBUTOR_ACCOUNT)
        expect_revert(error_message="Contributions: LEAD_CONTRIBUTOR role required")
    %}
    access_control.only_lead_contributor(PROJECT_ID);
    %{ stop_prank() %}

    return ();
}

@view
func test_only_lead_contributor_can_grant_member_role{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    fixture.initialize_with_lead_contributor();

    const NEW_PROJECT_MEMBER = 'member';

    %{ stop_prank = start_prank(ids.LEAD_CONTRIBUTOR_ACCOUNT) %}
    access_control.grant_member_role_for_project(PROJECT_ID, NEW_PROJECT_MEMBER);
    %{ stop_prank() %}

    %{ expect_revert(error_message="Contributions: LEAD_CONTRIBUTOR role required") %}
    access_control.grant_member_role_for_project(PROJECT_ID, NEW_PROJECT_MEMBER);

    return ();
}

@view
func test_only_lead_contributor_can_revoke_member_role{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    fixture.initialize_with_lead_contributor();

    const NEW_PROJECT_MEMBER = 'member';

    %{ stop_prank = start_prank(ids.LEAD_CONTRIBUTOR_ACCOUNT) %}
    access_control.revoke_member_role_for_project(PROJECT_ID, NEW_PROJECT_MEMBER);
    %{ stop_prank() %}

    %{ expect_revert(error_message="Contributions: LEAD_CONTRIBUTOR role required") %}
    access_control.revoke_member_role_for_project(PROJECT_ID, NEW_PROJECT_MEMBER);

    return ();
}

@view
func test_only_project_member_or_lead_contributor_revert_if_no_permission{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    fixture.initialize_with_lead_contributor();

    const NEW_PROJECT_MEMBER = 'member';

    %{ stop_prank = start_prank(ids.LEAD_CONTRIBUTOR_ACCOUNT) %}
    // With role LEAD_CONTRIBUTOR
    access_control.only_project_member_or_lead_contributor(PROJECT_ID);

    // With role LEAD_CONTRIBUTOR and PROJECT_MEMBER
    access_control.grant_member_role_for_project(PROJECT_ID, LEAD_CONTRIBUTOR_ACCOUNT);
    access_control.only_project_member_or_lead_contributor(PROJECT_ID);

    access_control.grant_member_role_for_project(PROJECT_ID, NEW_PROJECT_MEMBER);
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.NEW_PROJECT_MEMBER) %}
    // With role PROJECT_MEMBER
    access_control.only_project_member_or_lead_contributor(PROJECT_ID);
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.LEAD_CONTRIBUTOR_ACCOUNT) %}
    access_control.revoke_member_role_for_project(PROJECT_ID, NEW_PROJECT_MEMBER);
    %{ stop_prank() %}

    %{
        stop_prank = start_prank(ids.NEW_PROJECT_MEMBER)
        expect_revert(error_message="Contributions: PROJECT_MEMBER or LEAD_CONTRIBUTOR role required")
    %}
    access_control.only_project_member_or_lead_contributor(PROJECT_ID);
    %{ stop_prank() %}

    return ();
}

namespace fixture {
    func initialize{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        access_control.initialize(ADMIN);

        return ();
    }

    func initialize_with_lead_contributor{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() {
        access_control.initialize(ADMIN);
        %{ stop_prank = start_prank(ids.ADMIN) %}
        access_control.grant_lead_contributor_role_for_project(
            PROJECT_ID, LEAD_CONTRIBUTOR_ACCOUNT
        );
        %{ stop_prank() %}
        return ();
    }
}
