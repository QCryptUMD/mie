def sameMatrix(matrixOne, matrixTwo):
    diff = matrixOne.n(digits = 5) - matrixTwo.n(digits = 5)
    if diff.apply_map(lambda u:round(u,5)) == matrix(RR, [[0,0], [0,0]]):
        return True
    return False

# Translation Test 1
m = MIE(matrix(RR, [[1, 0], [0, 1]]), vector(RR, [10,5]).row())
m.integrate_parallel_cuts_hint(vector(RR, [0, 1]).row(), -.5, .5)
assert(m.mu == vector(RR, [10,5]).row())
assert(m.S == matrix(RR, [[1, 0], [0, .25]]))

# Translation Test 2
m = MIE(matrix(RR, [[1, 0], [0, 1]]), vector(RR, [-10,-5]).row())
m.integrate_parallel_cuts_hint(vector(RR, [0, 1]).row(), -.5, .5)
assert(m.mu == vector(RR, [-10,-5]).row())
assert(m.S == matrix(RR, [[1, 0], [0, .25]]))

# Translation Test 3
m = MIE(matrix(RR, [[1, 0], [0, 1]]), vector(RR, [-10,5]).row())
m.integrate_parallel_cuts_hint(vector(RR, [0, 1]).row(), -.5, .5)
assert(m.mu == vector(RR, [-10,5]).row())
assert(m.S == matrix(RR, [[1, 0], [0, .25]]))

# Translation Test 4
m = MIE(matrix(RR, [[1, 0], [0, 1]]), vector(RR, [10,-5]).row())
m.integrate_parallel_cuts_hint(vector(RR, [0, 1]).row(), -.5, .5)
assert(m.mu == vector(RR, [10,-5]).row())
assert(m.S == matrix(RR, [[1, 0], [0, .25]]))

# Rotation Test 1
m = MIE(matrix(RR, [[1, 0], [0, 1]]), vector(RR, [0,0]).row())
m.integrate_parallel_cuts_hint(vector(RR, [sqrt(3)/2, .5]).row(), -.5, .5)
assert(m.mu == vector(RR, [0,0]).row())
assert(sameMatrix(m.S, matrix(RR, [[ 0.43750, -0.32476],
[-0.32476, 0.81250]])))

# Rotation Test 2
m = MIE(matrix(RR, [[1, 0], [0, 1]]), vector(RR, [0,0]).row())
m.integrate_parallel_cuts_hint(vector(RR, [-.5, sqrt(3)/2]).row(), -.5, .5)
assert(m.mu == vector(RR, [0,0]).row())
assert(sameMatrix(m.S, matrix(RR, [[0.81250, 0.32476],
[0.32476, 0.43750]])))

# Rotation Test 3
m = MIE(matrix(RR, [[1, 0], [0, 1]]), vector(RR, [0,0]).row())
m.integrate_parallel_cuts_hint(vector(RR, [-sqrt(2)/2, -sqrt(2)/2]).row(), -.5, .5)
assert(m.mu == vector(RR, [0,0]).row())
assert(sameMatrix(m.S, matrix(RR, [[ 0.62500,-0.37500], [-0.37500, 0.62500]])))

# Translation and Rotation Test 1
m = MIE(matrix(RR, [[1, 0], [0, 1]]), vector(RR, [5,3]).row())
m.integrate_parallel_cuts_hint(vector(RR, [-.5, sqrt(3)/2]).row(), -.5, .5)
assert(m.mu == vector(RR, [5,3]).row())
assert(sameMatrix(m.S, matrix(RR, [[0.81250,0.32476],[0.32476, 0.43750]])))


# Translation and Rotation Test 2
m = MIE(matrix(RR, [[1, 0], [0, 1]]), vector(RR, [-1,-2]).row())
m.integrate_parallel_cuts_hint(vector(RR, [sqrt(2)/2, sqrt(2)/2]).row(), -.5, .5)
assert(m.mu == vector(RR, [-1,-2]).row())
assert(sameMatrix(m.S, matrix(RR, [[ 0.62500,-0.37500],
[-0.37500,0.62500]])))

