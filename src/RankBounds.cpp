// [[Rcpp::depends(RcppArmadillo)]]
#include <RcppArmadillo.h>
#include <algorithm>
#include <vector>

using namespace Rcpp;

static double leading_singular_value(const arma::mat& x) {
    arma::vec d;
    arma::svd(d, x);
    if (d.n_elem == 0) return 0.0;
    return d(0);
}

// [[Rcpp::export]]
arma::vec wedin_bound_resampling_cpp_draws(
    const arma::mat& X,
    const arma::mat& signal_basis,
    bool right_vectors,
    const arma::cube& draws
) {
    const arma::uword n_samples = draws.n_slices;
    arma::vec out(n_samples, arma::fill::zeros);

    if (signal_basis.n_cols == 0 || n_samples == 0) {
        return out;
    }
    if (draws.n_rows != signal_basis.n_rows) {
        Rcpp::stop("`draws` first dimension must equal nrow(signal_basis).");
    }
    if (draws.n_cols != signal_basis.n_cols) {
        Rcpp::stop("`draws` second dimension must equal ncol(signal_basis).");
    }

    for (arma::uword s = 0; s < n_samples; ++s) {
        arma::mat q;
        arma::mat r;
        arma::mat raw = draws.slice(s);
        arma::mat projected = raw - signal_basis * (signal_basis.t() * raw);
        arma::qr_econ(q, r, projected);
        arma::mat projection;
        if (right_vectors) {
            projection = X * q;
        } else {
            projection = q.t() * X;
        }
        out(s) = leading_singular_value(projection);
    }

    return out;
}

// [[Rcpp::export]]
arma::vec random_direction_bound_cpp_draws(
    int n_obs,
    const arma::ivec& dims,
    const Rcpp::List& draws_by_block
) {
    const int n_blocks = dims.n_elem;
    if (draws_by_block.size() != n_blocks) {
        Rcpp::stop("`draws_by_block` must have one array per block.");
    }
    if (n_blocks == 0) {
        return arma::vec();
    }

    arma::cube first = Rcpp::as<arma::cube>(draws_by_block[0]);
    const arma::uword n_samples = first.n_slices;
    arma::vec out(n_samples, arma::fill::zeros);

    std::vector<arma::cube> draws(n_blocks);
    int total_cols = 0;
    for (int k = 0; k < n_blocks; ++k) {
        draws[k] = Rcpp::as<arma::cube>(draws_by_block[k]);
        const arma::cube& draws_k = draws[k];
        if ((int)draws_k.n_rows != n_obs || (int)draws_k.n_cols != dims(k) ||
            draws_k.n_slices != n_samples) {
            Rcpp::stop("Each draw array must have dimensions n_obs x dims[k] x num_samples.");
        }
        total_cols += std::min(n_obs, dims(k));
    }

    for (arma::uword s = 0; s < n_samples; ++s) {
        arma::mat M(n_obs, total_cols);
        int col_start = 0;
        for (int k = 0; k < n_blocks; ++k) {
            arma::mat U;
            arma::vec d;
            arma::mat V;
            arma::svd_econ(U, d, V, draws[k].slice(s), "left");
            int n_cols = U.n_cols;
            M.cols(col_start, col_start + n_cols - 1) = U;
            col_start += n_cols;
        }
        double d1 = leading_singular_value(M);
        out(s) = d1 * d1;
    }

    return out;
}
