contract TestNamedToken {
    uint8 constant ERROR_1 = 1;
    uint8 constant ERROR_2 = 2;
    uint8 constant ERROR_3 = 3;
    uint8 constant ERROR_4 = 4;

    error Revert(uint8 idx);
    error ASkdhsadkjdhsakjdshakdsa();

    function revertWith(bool cond, uint8 idx) public pure {
        if (!cond) {
            revert Revert(idx);
        }
    }

    function test111() public {
        revertWith(1 == 2, ERROR_2);
    }

    function test23123() public {
        revert ASkdhsadkjdhsakjdshakdsa();
    }
}
