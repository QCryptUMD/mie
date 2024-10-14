# MIE

To create an MIE instance, intialize our class with the covariance matrix of the ellipsoid (self.S) and its center (self.mu).
Note that self.mu must be in row form.
m = MIE(matrix(RR, [[3,2], [2,9]]), vector(RR, [3,4]).row())


To integrate a hint, you need a direction vector (in row form) as well as two scalars, a and b.
m.integrate_parallel_cuts_hint(vector(RR, [sqrt(2)/2,sqrt(3)/2]).row(), -1,4)

To plot the ellipsoid in two or three dimensions, use the create_2d_plot or create_3d_plot functions.
plot_obj = create_2d_plot(m, vector(RR, [sqrt(2)/2,sqrt(3)/2]).row(), -1,4)
show(plot_obj)
