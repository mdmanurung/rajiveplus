# Simulator rank feasibility and realized numerical truth certificate

For K sample-aligned n-by-p[k] blocks, Joint rank j, and Individual ranks i[k],
the public uncentered construction must satisfy

```
j + i[k] <= min(n, p[k]), for every k;
sum(i[k]) <= (K - 1) * (n - j).
```

Let d=n-j be the ambient dimension of the Joint complement. For subspaces
V[k] of dimensions i[k] in that complement, repeated dimension/codimension
inequalities give

```
dim(intersection_k V[k]) >= max(0, sum(i[k]) - (K-1)*d).
```

Thus a positive lower bound makes extra all-block sharing unavoidable.
For generic independently sampled continuous subspaces the minimal
intersection dimension is attained almost surely, but these dimensional
conditions are not a certificate of a particular floating-point draw.
K=1 consequently requires i[1]=0. Pairwise or subset overlap is not forbidden.

The unchanged public generator's feasible matrices are certified after drawing.
There is no retry, hidden rank reduction, changed signal strength or centering.
Infeasible input fails before consuming RNG. A numerically uncertifiable
realization produces `rajiveplus_invalid_simulation`.

The internal certificate recomputes SVD bases from actual J, I and J+I matrices.
It checks achieved ranks, stored score/basis spaces, basis Gram errors,
Joint-space agreement, Joint/Individual orthogonality, all-block Individual
intersection zero, signal intersection j, and X=J+I+E. Cached certificates
are ignored. Finite real matrices and aligned dimensions/names are required.

Numerical rank uses `max(dim) * machine_epsilon * largest_singular_value`.
Geometry tolerance is separately 1e-10. Intersection dimension is the nullity
of stacked `(Id-P[k]) Q0`, with Q0 the smallest realized component space and
P[k] its other realized orthogonal projectors. This avoids n-by-n projector
allocation and does not reuse the generator's QR construction/intersection
helper. Projector-distance checks use two-sided projection residuals to avoid
catastrophic cancellation.

The attached compact certificate records tolerances, achieved ranks,
reconstruction/geometry errors and intersection singular values. Certification
does not imply estimator recovery, statistical calibration, good conditioning
at arbitrary scales, or stability under later preprocessing. Centered
experiments use the separately named centered generator and independently
certify its post-transform matrices in the n-1 dimensional sample space.

Tests include hand-constructed permissible pairwise overlap, forbidden
all-block overlap, feature capacity, saturated/zero ranks, K=1, corruption,
and a deterministic seed grid. Nine frozen feasible draws match original
matrices, fields and RNG states exactly in the matched environment.
