# ADR 0004: Wedin target and boundary behavior

## Status

Accepted as an internal candidate contract on 2026-09-19; not promoted to the
default after the paired candidate failed its frozen acceptance gate.

## Decision

For a block matrix `X` and an orthonormal estimated signal basis `U_r`, the
left-side resampler targets the operator norm `||Q_perp' X||_2`; the right-side
resampler targets `||X Q_perp||_2`. `Q_perp` is a Haar frame in the orthogonal
complement of the corresponding signal basis. Its frame rank is
`min(r, ambient_dimension - r)`. The bound divides the larger left/right draw
by the requested signal singular value `d[r]`, caps the ratio at one, and
squares it before aggregation.

The basis dimensions are `n x r` on the left and `p x r` on the right. A zero
signal rank returns zero draws. A saturated signal space has a zero-dimensional
complement and returns zero draws carrying
`boundary = "saturated_signal_space"`. A low-dimensional complement uses the
whole available complement; QR completion columns may not enter the signal
space.

## Validation

An independent R implementation projects fixed Gaussian draws,
re-orthonormalizes them in complement coordinates, and matches the candidate
boundary helper and its quantiles. Downstream rank decisions must be compared
under frozen method profiles and seeds; distributional similarity alone is not
acceptance. The default continues to use its frozen Wedin implementation.
