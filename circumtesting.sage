from numpy.linalg import inv as np_inv
from numpy.linalg import svd, det, cholesky
# from numpy.linalg import slogdet as np_slogdet
from numpy import array, trace, log, diag
from numpy import sqrt as np_sqrt
from scipy.linalg import sqrtm
from scipy.optimize import bisect, brenth, minimize_scalar, LinearConstraint, minimize
import numpy as np
import sys
from fpylll import *
from fpylll.algorithms.bkz2 import BKZReduction

ROUNDING_FACTOR = 2**64

def round_matrix_to_rational(M):
    A = matrix(ZZ, (ROUNDING_FACTOR * matrix(M)).apply_map(round))
    return matrix(QQ, A / ROUNDING_FACTOR)

def projection_matrix(A):
    """
    Construct the projection matrix orthogonally to Span(V)
    """
    S = A * A.T
    return A.T * S.inverse() * A

# Convert a 1*1 matrix into a scalar
def scal(M):
    assert M.nrows() == 1 and M.ncols() == 1, "This doesn't seem to be a scalar."
    return M[0, 0]

# Finds the square root of a matrix and its inverse as well
def square_root_inverse_degen(S, B=None, assume_full_rank=False):
    """ Compute the determinant of a symmetric matrix
    sigma (m x m) restricted to the span of the full-rank
    rectangular (k x m, k <= m) matrix V
    """
    
    if assume_full_rank:
        P = identity_matrix(S.ncols())

    elif not assume_full_rank and B is None:
        # Get an orthogonal basis for the Span of B
        V = S.echelon_form()
        V = V[:V.rank()]
        P = projection_matrix(V)

    else:
        P = projection_matrix(B)

    # make S non-degenerated by adding the complement of span(B)
    C = identity_matrix(S.ncols()) - P
    # Take matrix sqrt via SVD, then inverse
    # S = adjust_eigs(S)
    
    u, s, vh = svd(array(S + C, dtype=float))
    L_inv = np_inv(vh) @ np_inv(np_sqrt(diag(s))) @ np_inv(u)
    # L_inv = np_inv(sqrtm(array(S + C, dtype=float)))
    
    L_inv = np_inv(cholesky(array(S + C, dtype=float))).T
    L_inv = round_matrix_to_rational(L_inv)
    L = L_inv.inverse()


    # scipy outputs complex numbers, even for real valued matrices. Cast to real before rational.
    #L = round_matrix_to_rational(u @ np_sqrt(diag(s)) @ vh)

    return L, L_inv

def create_2d_plot(mie, direction, a, b):
    from copy import deepcopy

    old_mie = deepcopy(mie)
    mie.integrate_parallel_cuts_hint(direction, a,b)

    p = old_mie.plot2d(0) + mie.plot2d(0.75)

    return p


# From the papers:
# intuitive form of ellipse: E = {c + Au : u in S^2}
# ellipoid norm form:        E = {x in R^n : <X(x-c), x-c> <= 1}
# Here, Sigma = X, and since sqrt(X) = A, it follows that
# A = sqrt({Sigma})

def plot_2d(a, c):
    p = circle([0,0],1)
    # p += line([(-1+sqrt(2)/4,1+sqrt(2)/4), (1 + sqrt(2)/4,-1+sqrt(2)/4)])
    for ind in range(0,360):
        n_x = a[0][0]*cos(ind)+a[0][1]*sin(ind)+ c[0]
        n_y = a[1][0]*cos(ind)+a[1][1]*sin(ind)+ c[1]
        p2 = point((n_x,n_y),rgbcolor=hue(0))
        p += p2
        p += line([[-1,0.6],[1, -1.4]])
    return p


class MIE:
    # right now only checking for positive definite matrix, but we
    # technically should verify poitive semidefinite
    def __init__(self, S, mu):
        # check out how Hunter did this check
        if not S.is_positive_definite():
            print("ERROR: must input a positive definite matrix")
            return
        self.S = S
        self.mu = mu

    def dim(self):
        return len(list(self.mu.transpose()))

    # WARNING: this is done assuming that self.S is in the intiuitve form
    def plot2d(self, hueColor):
        p = plot([], aspect_ratio = 1)
        (sqrt_mat, sqrt_inv_mat) = square_root_inverse_degen(self.S)
        print(sqrt_mat.n())
        for ind in range(0,360):
            rotation_vec = vector(RR, [cos(ind), sin(ind)]).row()
            new_point = rotation_vec * sqrt_mat
            new_point += self.mu
            p2 = point(new_point,rgbcolor=hue(hueColor))
            p += p2
            p += line([[-1,0.6],[1, -1.4]])
        return p
        
    def integrate_ineq_hint(self, v, bound):
        """
         <v, secret> <= bound
        See Eq (3.1.11), Eq. (3.1.12) in Lovasz's the Ellipsoid Method.
        """
        dim_ = self.dim()
  
        ellipsoid_norm = sqrt((v * self.S * v.transpose())[0][0])
        
        # checks if inside ellipse
        alpha = ((self.mu*v.transpose())[0][0] - bound) / ellipsoid_norm

        if alpha < -1 or alpha > 1:
            raise InvalidHint("Redundant hint! Cut outside ellipsoid!")

        if -1 <= alpha and alpha <= -1 /dim_:
            return
        
        b = (1 / ellipsoid_norm) * v * self.S.transpose()

        coeff = (1 + dim_ * alpha) / (dim_ + 1)
        print(dim_)
        coeff2 = (dim_ * dim_) / (dim_ * dim_ - 1) * (1 - alpha * alpha)

        self.mu -= coeff * b
        self.S -= (2 * coeff) / (1 + alpha) * b.transpose() * b
        self.S *= coeff2
        print(f"sssss{self.S.n()}")
        print(f"muuuu{self.mu.n()}")
    # NOTE: in the toolkit everything is done with rows instead of columns
    # go about this assuming direction is a unit vector from now on,
    # this matches the definition of what one expects when working with a
    # "direction" vector

    # but the user need not worry about this, we'll normalize it
    
    def integrate_parallel_cuts_hint(self, direction, a, b):
        # the meaning of the signs here is kind of superfluous, this is just
        # to determine where everything is relative to the center of the
        # ellipsoid
        # 
        # a and b are distances from the center of the ellipsoid to the
        # two hyperplanes in the hint, along the direction of direction

        # now a and b are vectors representing the center of the ellipse
        # to the hyperplanes
        direction = direction / direction.norm()
        a = a * direction
        b = b * direction

        print(f"a: {a}, b: {b}")

        # there are problems if the direction is not in the column space
        # right now just error out
        try:
            self.S.solve_left(a)
            self.S.solve_left(b)
        except:
            print("a or b along direction not in column space of Sigma")
            return

        # A as above := sqrt_inv_mat
        (sqrt_mat, sqrt_inv_mat) = square_root_inverse_degen(self.S)
        print(f"sqrt: {sqrt_mat}, sqrt_inv: {sqrt_inv_mat}")

        # Step 1, subtract
        # before: E = mu + (sqrt_inv_mat)B_n
        # after: E = (sqrt_inv_mat)B_n
        # note that this applies to everyone inside the ball, and since
        # we only care about a and b right now, only apply to a and b
        # however this step shouldn't matter I think because a and b
        # were defined with repect to the center
        # a -= self.mu
        # b -= self.mu

        # make direction actual direction (scaled) and treat a and b as vectors from this

        # this is to accommodate for step 2 in our drawing
        # Step 2: stretch the ellipsoid into ball
        # before: E = (sqrt_inv_mat)B_n
        # after: E = B_n
        # to get back to a ball for easy rotations, we must "stretch"
        # the ellipsoid back into a ball, which is done by
        # multiplying by sqrt_mat

        a_scaled = a * sqrt_inv_mat.transpose()
        b_scaled = b * sqrt_inv_mat.transpose()

        print(f"a_scaled: {a_scaled}, b_scaled: {b_scaled}")
        
        # this is to apply a Householder transformation
        e = zero_vector(self.dim()).row()
        print("after zero")
        e[0] = 1
        print("make it e1")

        refl = (e - direction / norm(direction)) / 2
        
        # this step might cause issues, ellipsoids are over the reals,
        # but when we multiply it by the lattice, this thing has to be rational
        # a solution is to round to the nearest rational with some precision,
        # but this can cause problems when done over and over again
        # for a single hint, this _should_ be fine, still keep note of this
        # though
        # since we are rotating and rotating back, some things should cancel out
        # intuitively, but we might have to figure this out later
        # if estimating, we need not worry about this
        G = AffineGroup(self.dim(), RR) # could be rationals, check back with this later
        print("about to make refl_mat")

        if refl == zero_vector(self.dim()).row():
            print("We have a zero vector, don't rotate")
            refl_mat = G(identity_matrix(self.dim()), zero_vector(self.dim()))
        else:
            copy_refl = []
            for val in list(refl.transpose()):
                copy_refl.append(val[0])
            refl_mat = G.reflection(copy_refl)
        print(f"got refl_mat\n\n\n: {refl_mat}\n\n\n")


        # Step 3: rotate the ball such that a_scaled and b_scaled are aligned
        # with the first coordinate
        # before: E = B_n
        # after: E = B_n (rotated in some way)
        a_scaled_rot = a_scaled * matrix(RR, refl_mat.A().transpose())  + vector(RR,refl_mat.b()).row()
        b_scaled_rot = b_scaled * matrix(RR, refl_mat.A().transpose()) + vector(RR,refl_mat.b()).row()
        print(f"rotated guys: {a_scaled_rot}, {b_scaled_rot}")

        # now we have a unit ball with the first coordinate aligned, make sure
        # a and b are witihin this ball (since they are scalar multiples of
        # e_1, we only have to check the first coordinate)
        alpha = a_scaled_rot[0][0]
        beta = b_scaled_rot[0][0]

        alpha, beta = min(alpha, beta), max(alpha, beta)

        print(f"{alpha}, {beta}")

        # in the future we might want to make it so that we assume the extreme
        # hyperplane is the tangent plane of the hypersphere
        if abs(alpha) > 1 or abs(beta) > 1:
            #raise InvalidHint("alpha or beta is too big to be useful")
            print("alpha or beta are too big to be useful")

        # this is a and b in the paper, changed names to avoid confusion
        matrix_first = 0
        matrix_rest = 0
        tau = 0
        n = self.dim()
        left_condition = 4 * n * (1 - alpha) * (1 + alpha)
        right_condition = (n + 1) * (n + 1) * (beta - alpha) * (beta + alpha)

        print("before mess")
        if alpha == -beta:
            print("cond 1")
            tau = 0
            matrix_first = beta
            matrix_rest = 1
        elif left_condition < right_condition:
            print("cond 2")
            tau = 0.5 * (alpha + sqrt(alpha * alpha + left_condition / pow(n + 1, 2)))
            matrix_first = tau - alpha
            matrix_rest = sqrt(matrix_first * (matrix_first + n * tau))
        else: # (left_condition >= right_condition)
            print("cond 3")
            denom = 2 * (sqrt((1 - alpha) * (1 + alpha)) - sqrt((1 - beta) * (1 + beta)))
            tau = 0.5 * (beta + alpha)
            matrix_first = 0.5 * (beta - alpha)
            matrix_rest = sqrt(matrix_first ** 2 + pow((beta ** 2 - alpha ** 2) / denom, 2))

        print(f"{tau}, {matrix_first}, {matrix_rest}")
        print("after mess")
            

        # this is to build up the diagonal matrix as in the paper
        print("zero_vector")
        z = zero_vector(RR, n)
        print("matrix_first")
        z[0] = matrix_first
        print("about to enter for loop")
        for ind in range(1, n):
            z[ind] = matrix_rest
        A = diagonal_matrix(z)
        c = zero_vector(RR, n)
        c[0] = tau
        c = c.row()

        print(f"before A: {A}, c: {c}")
        
        # this can probably be made better with matrix mulitplication
        # and/or matrix augmentation, but we can't figure it out right now
        # also rotate c here
        # might be able to apply either the matrix, or its transpose at the
        # worst because this is an orthonormal matrix
        refl_mat_inverse = refl_mat.A().inverse()
        print(f"unt{refl_mat.A()}")
        print(f"inv{refl_mat_inverse}")
        for ind in range(self.dim()):
            v = vector(A[:,ind])
            reflected = refl_mat_inverse * (v - refl_mat.b())
            A[:,ind] = reflected

        print(f"after A: {A}, c: {c}")
        # transform it back and mutate the starting matrix
        # apply sqrt_inv to c
        # Dana mentioned that we might want self.S to be of the form
        # inv_sqrt_mat * S * sqrt_mat
        # because of the properties that we have
        # xSx^T <= 1 (perhaps in order to mirror this property we would have
        #    (x * sqrt_inv_mat) * S * (x * sqrt_inv_mat)^T
        # <=> x * (sqrt_inv_mat * S * inv_mat) * x^T
        # self.S = sqrt_inv_mat * A
        # self.S = (A.transpose() * self.S.inverse() * A).inverse
        a_s = sqrt_mat*A
        
        self.S = (a_s*a_s.transpose())
        print(f"new self.S: {self.S.n()}")
        #self.S = matrix(RR, [[cos(-pi/4), sin(-pi/4)],[-cos(-pi/4),sin(-pi/4)]]) * self.S
        print(f"new self.S: {self.S}")

        c = c * matrix(RR, refl_mat.A().transpose()) + vector(RR, refl_mat.b()).row()
        c = c * sqrt_inv_mat.transpose()
        self.mu += c
m = MIE(identity_matrix(RR, 2), vector(RR, [0,0]).row())
create_2d_plot(m, vector(RR, [0, 1]).row(), -0.5, 0.5)