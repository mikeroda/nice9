.DATA 5
.DATA 500
0: LDC 1, 0(0)
1: JNE 1, 4(7)
2: LD  1, 1(0)
3: ADD 1, 1, 1
4: OUT 1, 1, 1
5: LDA 7, 3(7)
6: LD  1, 2(0)
7: ADD 1, 1, 1
8: OUT 1, 1, 1
9: OUTNL 0,0,0
