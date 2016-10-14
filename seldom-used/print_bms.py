def print_bms_members (bms):
    words = bms.GetChildMemberWithName("words")
    nwords = int(bms.GetChildMemberWithName("nwords").GetValue())

    ret = 'nwords = {0} bitmap: '.format(nwords,)
    for i in range(0, nwords):
        ret += hex(int(words.GetChildAtIndex(0, lldb.eNoDynamicValues, True).GetValue()))

    return ret
