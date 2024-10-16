from numpy.linalg import inv as np_inv
from numpy.linalg import svd, det, cholesky
from numpy import array, trace, log, diag
from numpy import sqrt as np_sqrt
from scipy.linalg import sqrtm
import numpy as np
from scipy.linalg import fractional_matrix_power
from sage.matrix.constructor import vector_on_axis_rotation_matrix

ROUNDING_FACTOR = 2**64

def approximateMatrixSimilarity(matrixOne, matrixTwo, dim):
    matrixOne = matrixOne.apply_map(lambda u:round(u,5))
    matrixTwo = matrixTwo.apply_map(lambda u:round(u,5))
    diff = (matrixOne - matrixTwo).apply_map(lambda u:round(u,5))
    entries = [x for row in diff for x in row]
    return all([x == 0 for x in entries])

def approximateVectorSimilarity(vectorOne, vectorTwo):
    vectorOne = vector(RR, [round(x, 5) for x in vectorOne[0]])
    vectorTwo = vector(RR, [round(x, 5) for x in vectorTwo[0]])
    diff = vector(RR, [round(x, 5) for x in (vectorOne - vectorTwo)])
    return all([x == 0 for x in diff])

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

# Computes the MIE of a ball rotated so that the cutting hyperplanes are
# orthogonal to the first standard basis vector. alpha and beta here are the
# distances from the center of the ball to each of the hyperplanes.

# https://www.researchgate.net/publication/233346563_Symmetry_of_convex_sets_and_its_applications_to_the_extremal_ellipsoids_of_convex_bodies
# See theorem 6.1
def mie_unit_ball(alpha, beta, dim):
    alpha, beta = min(alpha,beta), max(alpha,beta)
    alpha, beta = max(alpha, -1), min(beta, 1)
    if alpha >= 1 or beta <= -1:
        raise Exception("ERROR: hyperplanes fall outside the ellipsoid")

    # this is a and b in the paper, changed names to avoid confusion
    matrix_first, matrix_rest, tau = 0, 0, 0
    n = dim
    left_condition = 4 * n * (1 - alpha) * (1 + alpha)
    right_condition = (n + 1) * (n + 1) * (beta - alpha) * (beta + alpha)

    if alpha == -beta:
        tau = 0
        matrix_first = beta
        matrix_rest = 1
    elif left_condition < right_condition:
        intermediate = sqrt(alpha ** 2 + left_condition / ((n+1) ** 2))
        tau = 0.5 * (alpha + intermediate)
        matrix_first = tau - alpha
        matrix_rest = sqrt(matrix_first * (matrix_first + n * tau))
    else: # (left_condition >= right_condition)
        denom = 2 * (sqrt((1 - alpha) * (1 + alpha)) - sqrt((1 - beta) * (1 + beta)))
        tau = 0.5 * (beta + alpha)
        matrix_first = 0.5 * (beta - alpha)
        matrix_rest = sqrt(matrix_first ** 2 + ((beta ** 2 - alpha ** 2) / denom) ** 2)

    z = zero_vector(RR, n)
    z[0] = matrix_first
    for ind in range(1, n):
        z[ind] = matrix_rest
    A = diagonal_matrix(z)
    c = zero_vector(RR, n)
    c[0] = tau
    c = c.row()
    return A, c

# Plots a two-dimensional ellipsoid, the cutting hyperplanes (lines), and the MIE
#
# @mie: the mie instance
# @direction, a, b: defines two hyperplanes by the normal of the hyperplane
#                   and their distances relative to the center of the ellipsoid
def create_2d_plot(mie, direction, a, b):
    (sqrt_mat, sqrt_inv_mat) = square_root_inverse_degen(mie.S)
    
    # Add the lines
    major_axis_length = max(sqrt_mat.transpose().columns()[0].norm(), sqrt_mat.transpose().columns()[1].norm())
    unit_direction = direction/direction.norm()
    
    # Find the 2 points that are a distance of 'a' and 'b' away from the center
    first_center = unit_direction * a + mie.mu
    second_center = unit_direction * b + mie.mu

    # Find the points that are far away from the first and second centers in the direction of the parallel cuts.
    distance_from_center = vector(RR, [-unit_direction[0][1], unit_direction[0][0]]).row() * major_axis_length
    
    first_line = list(first_center + distance_from_center)
    first_line.append(list(first_center - distance_from_center)[0])
    
    second_line = list(second_center + distance_from_center)
    second_line.append(list(second_center - distance_from_center)[0])
    
    # Integrate parallel cuts
    old_mie = deepcopy(mie)
    mie.integrate_parallel_cuts_hint(direction, a,b)

    p = old_mie.plot2d(1) + mie.plot2d(0)
        
    p += line(first_line, color = "deepskyblue")
    p += line(second_line, color = "deepskyblue")

    return p

# Plots a three-dimensional ellipsoid, the cutting hyperplanes (planes), and the MIE
#
# @mie: the mie instance
# @direction, a, b: defines two hyperplanes (planes) by the normal of the hyperplane
#                   and their distances relative to the center of the ellipsoid
def create_3d_plot(mie, direction, a, b):
    var('x, y, z')
    direction = direction/direction.norm()
    
    # Find the maximum distance we need to go in one direction
    (sqrt_mat, sqrt_inv_mat) = square_root_inverse_degen(mie.S)
    major_axis_length = max(sqrt_mat.transpose().columns()[0].norm(), sqrt_mat.transpose().columns()[1].norm(), sqrt_mat.transpose().columns()[2].norm())
    
    # Find the lower and upper ranges
    lower_range = mie.mu - vector(RR, [major_axis_length,major_axis_length,major_axis_length ]).row()
    upper_range = mie.mu + vector(RR, [major_axis_length,major_axis_length,major_axis_length ]).row()
    
    vars_translated = vector((vector((x,y,z)).row() - mie.mu).list())
    plane_equation = vector(RR, direction.list()).dot_product(vars_translated)
    
    # Integrate parallel cuts
    old_mie = deepcopy(mie)
    mie.integrate_parallel_cuts_hint(direction, a,b)

    p = old_mie.plot3d(1) + mie.plot3d(0)
    p += implicit_plot3d(plane_equation - a, (x, lower_range[0][0], upper_range[0][0]), (y, lower_range[0][1], upper_range[0][1]), (z, lower_range[0][2], upper_range[0][2]), opacity = .3)
    p += implicit_plot3d(plane_equation - b, (x, lower_range[0][0], upper_range[0][0]), (y, lower_range[0][1], upper_range[0][1]), (z, lower_range[0][2], upper_range[0][2]), opacity = .3)

    return p

# From the papers:
# intuitive form of ellipse: E = {c + Au : u in B_n}
# ellipoid norm form:        E = {x in R^n : <X(x-c), x-c> <= 1}
# Here, X = Sigma^(-1), and A = X^(-1/2) = Sigma^(1/2)
class MIE:
    def __init__(self, S, mu):
        # check out how Hunter did this check
        if not np.all(np.linalg.eigvals(S) >= 0):
            raise Exception("ERROR: must input a positive semidefinite matrix")
        self.S = S
        self.mu = mu

    def dim(self):
        return len(list(self.mu.transpose()))

    # Plots the two-dimensional ellipsoid given by E = {x in R^2 : <self.S(x-self.mu), x-self.mu> <= 1}
    # Returns a plot object containing all the mapped points
    # @colorValue: 0 or 1, denotes the color of the points
    def plot2d(self, colorValue):
        p = plot([], aspect_ratio = 1)
        (sqrt_mat, sqrt_inv_mat) = square_root_inverse_degen(self.S)
        
        # Since the ellipse is of the form (self.Sigma)^(1/2) * Ball + self.mu, we can plot the ellipse by 
        # plotting where the points of the unit circle map to.
        for ind in range(0,360):
            original_point = vector(RR, [cos(ind), sin(ind)]).row()
            new_point = original_point * sqrt_mat + self.mu
            p += point(new_point,color="black" if colorValue == 1 else "magenta")
            
        return p
    
    # Plots the three-dimensional ellipsoid given by E = {x in R^3 : <self.S(x-self.mu), x-self.mu> <= 1}
    # Returns a plot object containing all the mapped points
    # @colorValue: 0 or 1, denotes the color of the points
    
    def plot3d(self, colorValue):
        p = plot([], aspect_ratio = 1)
        (sqrt_mat, sqrt_inv_mat) = square_root_inverse_degen(self.S)
        # Since the ellipse is of the form (self.Sigma)^(1/2) * Ball + self.mu, we can plot the ellipse by 
        # plotting where the points of a unit sphere map to
        # We use spherical coordinates to parametrize the unit sphere
        for polar_angle in range(0,180, 5):
            for azimuthal_angle in range(0,360, 10):
                original_point = vector(RR, [sin(polar_angle) * cos(azimuthal_angle), sin(polar_angle) * sin(azimuthal_angle), cos(polar_angle)]).row()
                
                new_point = original_point * sqrt_mat + self.mu
                p += point(new_point, color="black" if colorValue == 1 else "magenta")
                
        return p    
    
    # NOTE: in the toolkit everything is done with rows instead of columns
    # go about this assuming direction is a unit vector from now on,
    # this matches the definition of what one expects when working with a
    # "direction" vector

    # @self: an MIE instance, which is made up of a covariance matrix and
    #        the center mu of an ellipsoid
    # @direction: the direction of the parallel hyperplanes, does not have
    #             to be normalized
    # @a, b: the distance from the center of the ellipsoid to each hyperplane,
    #        in the direction indicated by direction
    #
    # The hyperplanes are given by the following formulas:
    # direction * (x - mu) = a
    # direction * (x - mu) = b
    def integrate_parallel_cuts_hint(self, direction, a, b):
        # if a == b then there is no space between the generated hyperplanes
        # for an MIE to fit, so this is an error
        if (a == b):
            print("Invalid Hint")
            return
        
        # Normalize the direction
        direction = direction / direction.norm()

        # there are problems if the direction is not in the column space
        # right now just error out
        try:
            self.S.solve_left(a * direction)
            self.S.solve_left(b * direction)
        except:
            print("a or b along direction not in column space of Sigma")
            return

        # The high-level idea of our procedure follows (see the
        # accompanying paper for pictures at each step:
        #
        # To start we have the covariance matrix of the ellipsoid E as follows:
        # E = {x : (x - mu) * (Sigma^{-1}) * (x - mu)^T <= 1}
        #   (We call this the "ellipsoid norm form" of the ellipsoid)
        #
        # We want to turn our ellipsoid into a ball rotated some way so that
        # the conditions in the ellipsoid paper are satisfied, and this is made
        # easier by equivalently defining our ellipsoid by
        # E = {x * sqrt(Sigma) + mu : ||x|| <= 1}
        #   = B_n * sqrt(Sigma) + mu (informally speaking)
        #   (We call this the "stretched ball form" of the ellipsoid)
        #
        # Step 1: Translate the space so that the center of the ellipsoid is at
        #         the origin
        # Step 2: Multiply the space by sqrt(Sigma)^{-1} to undo the scaling on
        #         the ball in the above definition so that we have a ball
        #         centered at the origin (note that the original hyperplanes
        #         may have been scaled and rotated in this process)
        # Step 3: Rotate the space so that normals to the hyperplanes are
        #         aligned with the first standard basis vector
        # Step 4: Perform the MIE algorithm from the paper
        # Step 5: Undo all the previous steps with the new ellipsoid so that by
        #         the end we have an MIE with respect to the ellipsoid we
        #         started with

        # obtain sqrt(Sigma) and sqrt(Sigma)^{-1} respectively
        (sqrt_mat, sqrt_inv_mat) = square_root_inverse_degen(self.S)

        # get the new hyperplanes and direction resulting from Step 2
        direction = direction * sqrt_mat.transpose()
        final_a = abs(a)/direction.norm()
        final_b = abs(b)/direction.norm()
        
        # Find how much we have to rotate direction to line up with the x axis
        rot_mat = vector_on_axis_rotation_matrix(vector(RR, direction.list()), 0)
        inv_rot_mat = matrix(RR, fractional_matrix_power(rot_mat, -1))
        
        # Step 3: rotate the ball such that direction are in
        # the direction of the first standard basis vector
        rotated_direction = direction * rot_mat.transpose()
        sign_a = 1 if rotated_direction[0] * a > 0 else -1
        sign_b = 1 if rotated_direction[0] * b > 0 else -1
        alpha = sign_a * final_a
        beta = sign_b * final_b

        # Step 4: Apply the MIE algorithm
        A, c = mie_unit_ball(alpha, beta, self.dim())

        # Step 5:
        # transform it back and mutate the starting matrix
        A = inv_rot_mat * A   
        # Dana mentioned that we might want self.S to be of the form
        # inv_sqrt_mat * S * sqrt_mat
        # because of the properties that we have
        # xSx^T <= 1 (perhaps in order to mirror this property we would have
        #    (x * sqrt_inv_mat) * S * (x * sqrt_inv_mat)^T
        # <=> x * (sqrt_inv_mat * S * inv_mat) * x^T
        
        a_s = A.transpose() * sqrt_mat 
        self.S =  a_s.transpose() * a_s
        # apply sqrt_inv to c
        c = c * inv_rot_mat.transpose()
        c = c * sqrt_mat
        self.mu += c
