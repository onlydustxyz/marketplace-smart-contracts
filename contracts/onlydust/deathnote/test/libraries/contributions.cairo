%lang starknet

from starkware.cairo.common.uint256 import Uint256

from onlydust.deathnote.core.contributions.library import Contribution, Status

namespace assert_contribution_that:
    func id_is{contribution : Contribution}(expected : felt):
        let actual = contribution.id
        with_attr error_message("Invalid contribution ID: expected {expected}, actual {actual}"):
            assert expected = actual
        end
        return ()
    end

    func project_id_is{contribution : Contribution}(expected : felt):
        let actual = contribution.project_id
        with_attr error_message("Invalid project ID: expected {expected}, actual {actual}"):
            assert expected = actual
        end
        return ()
    end

    func status_is{contribution : Contribution}(expected : felt):
        let actual = contribution.status
        with_attr error_message(
                "Invalid contribution status: expected {expected}, actual {actual}"):
            assert expected = actual
        end
        return ()
    end

    func contributor_is{contribution : Contribution}(expected : Uint256):
        let actual = contribution.contributor_id
        with_attr error_message("Invalid contributor: expected {expected}, actual {actual}"):
            assert expected = actual
        end
        return ()
    end

    func validator_is{contribution : Contribution}(expected : felt):
        let actual = contribution.validator_account
        with_attr error_message("Invalid validator: expected {expected}, actual {actual}"):
            assert expected = actual
        end
        return ()
    end
end
