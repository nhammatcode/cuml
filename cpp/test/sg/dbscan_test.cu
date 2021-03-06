/*
 * Copyright (c) 2018-2020, NVIDIA CORPORATION.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <common/cudart_utils.h>
#include <gtest/gtest.h>
#include <cuda_utils.cuh>
#include <vector>

#include <cuml/cluster/dbscan.hpp>
#include <cuml/common/cuml_allocator.hpp>
#include <cuml/cuml.hpp>
#include <cuml/datasets/make_blobs.hpp>
#include <cuml/metrics/metrics.hpp>

#include <linalg/cublas_wrappers.h>
#include <linalg/transpose.h>

#include <test_utils.h>

#include <common/device_buffer.hpp>
#include <cuml/common/logger.hpp>

namespace ML {

using namespace MLCommon;
using namespace Datasets;
using namespace Metrics;
using namespace std;

template <typename T, typename IdxT>
struct DbscanInputs {
  IdxT n_row;
  IdxT n_col;
  IdxT n_centers;
  T cluster_std;
  T eps;
  int min_pts;
  size_t max_bytes_per_batch;
  unsigned long long int seed;
};

template <typename T, typename IdxT>
::std::ostream &operator<<(::std::ostream &os,
                           const DbscanInputs<T, IdxT> &dims) {
  return os;
}

template <typename T, typename IdxT>
class DbscanTest : public ::testing::TestWithParam<DbscanInputs<T, IdxT>> {
 protected:
  void basicTest() {
    cumlHandle handle;

    params = ::testing::TestWithParam<DbscanInputs<T, IdxT>>::GetParam();

    device_buffer<T> out(handle.getDeviceAllocator(), handle.getStream(),
                         params.n_row * params.n_col);
    device_buffer<IdxT> l(handle.getDeviceAllocator(), handle.getStream(),
                          params.n_row);

    make_blobs(handle, out.data(), l.data(), params.n_row, params.n_col,
               params.n_centers, true, nullptr, nullptr, params.cluster_std,
               true, -10.0f, 10.0f, params.seed);

    allocate(labels, params.n_row);
    allocate(labels_ref, params.n_row);

    MLCommon::copy(labels_ref, l.data(), params.n_row, handle.getStream());

    CUDA_CHECK(cudaStreamSynchronize(handle.getStream()));

    dbscanFit(handle, out.data(), params.n_row, params.n_col, params.eps,
              params.min_pts, labels, params.max_bytes_per_batch);

    CUDA_CHECK(cudaStreamSynchronize(handle.getStream()));

    score = adjustedRandIndex(handle, labels_ref, labels, params.n_row);

    if (score < 1.0) {
      auto str =
        arr2Str(labels_ref, params.n_row, "labels_ref", handle.getStream());
      CUML_LOG_DEBUG("y: %s", str.c_str());
      str = arr2Str(labels, params.n_row, "labels", handle.getStream());
      CUML_LOG_DEBUG("y_hat: %s", str.c_str());
      CUML_LOG_DEBUG("Score = %lf", score);
    }
  }

  void SetUp() override { basicTest(); }

  void TearDown() override {
    CUDA_CHECK(cudaFree(labels));
    CUDA_CHECK(cudaFree(labels_ref));
  }

 protected:
  DbscanInputs<T, IdxT> params;
  IdxT *labels, *labels_ref;

  double score;
};

const std::vector<DbscanInputs<float, int>> inputsf2 = {
  {500, 16, 5, 0.01, 2, 2, (size_t)100, 1234ULL},
  {1000, 1000, 10, 0.01, 2, 2, (size_t)13e3, 1234ULL},
  {20000, 10000, 10, 0.01, 2, 2, (size_t)13e3, 1234ULL},
  {20000, 100, 5000, 0.01, 2, 2, (size_t)13e3, 1234ULL}};

const std::vector<DbscanInputs<float, int64_t>> inputsf3 = {
  {50000, 16, 5, 0.01, 2, 2, (size_t)9e3, 1234ULL},
  {500, 16, 5, 0.01, 2, 2, (size_t)100, 1234ULL},
  {1000, 1000, 10, 0.01, 2, 2, (size_t)9e3, 1234ULL},
  {50000, 16, 5l, 0.01, 2, 2, (size_t)9e3, 1234ULL},
  {20000, 10000, 10, 0.01, 2, 2, (size_t)9e3, 1234ULL},
  {20000, 100, 5000, 0.01, 2, 2, (size_t)9e3, 1234ULL}};

const std::vector<DbscanInputs<double, int>> inputsd2 = {
  {50000, 16, 5, 0.01, 2, 2, (size_t)13e3, 1234ULL},
  {500, 16, 5, 0.01, 2, 2, (size_t)100, 1234ULL},
  {1000, 1000, 10, 0.01, 2, 2, (size_t)13e3, 1234ULL},
  {100, 10000, 10, 0.01, 2, 2, (size_t)13e3, 1234ULL},
  {20000, 10000, 10, 0.01, 2, 2, (size_t)13e3, 1234ULL},
  {20000, 100, 5000, 0.01, 2, 2, (size_t)13e3, 1234ULL}};

const std::vector<DbscanInputs<double, int64_t>> inputsd3 = {
  {50000, 16, 5, 0.01, 2, 2, (size_t)9e3, 1234ULL},
  {500, 16, 5, 0.01, 2, 2, (size_t)100, 1234ULL},
  {1000, 1000, 10, 0.01, 2, 2, (size_t)9e3, 1234ULL},
  {100, 10000, 10, 0.01, 2, 2, (size_t)9e3, 1234ULL},
  {20000, 10000, 10, 0.01, 2, 2, (size_t)9e3, 1234ULL},
  {20000, 100, 5000, 0.01, 2, 2, (size_t)9e3, 1234ULL}};

typedef DbscanTest<float, int> DbscanTestF_Int;
TEST_P(DbscanTestF_Int, Result) { ASSERT_TRUE(score == 1.0); }

typedef DbscanTest<float, int64_t> DbscanTestF_Int64;
TEST_P(DbscanTestF_Int64, Result) { ASSERT_TRUE(score == 1.0); }

typedef DbscanTest<double, int> DbscanTestD_Int;
TEST_P(DbscanTestD_Int, Result) { ASSERT_TRUE(score == 1.0); }

typedef DbscanTest<double, int64_t> DbscanTestD_Int64;
TEST_P(DbscanTestD_Int64, Result) { ASSERT_TRUE(score == 1.0); }

INSTANTIATE_TEST_CASE_P(DbscanTests, DbscanTestF_Int,
                        ::testing::ValuesIn(inputsf2));

INSTANTIATE_TEST_CASE_P(DbscanTests, DbscanTestF_Int64,
                        ::testing::ValuesIn(inputsf3));

INSTANTIATE_TEST_CASE_P(DbscanTests, DbscanTestD_Int,
                        ::testing::ValuesIn(inputsd2));

INSTANTIATE_TEST_CASE_P(DbscanTests, DbscanTestD_Int64,
                        ::testing::ValuesIn(inputsd3));

template <typename T>
struct DBScan2DArrayInputs {
  const T *points;
  const int *out;
  size_t n_row;
  // n_out allows to compare less labels than we have inputs
  // (some output labels can be ambiguous)
  size_t n_out;
  T eps;
  int min_pts;
};

template <typename T>
class Dbscan2DSimple : public ::testing::TestWithParam<DBScan2DArrayInputs<T>> {
 protected:
  void basicTest() {
    cumlHandle handle;

    params = ::testing::TestWithParam<DBScan2DArrayInputs<T>>::GetParam();

    allocate(inputs, params.n_row * 2);
    allocate(labels, params.n_row);
    allocate(labels_ref, params.n_out);

    MLCommon::copy(inputs, params.points, params.n_row * 2, handle.getStream());
    MLCommon::copy(labels_ref, params.out, params.n_out, handle.getStream());
    CUDA_CHECK(cudaStreamSynchronize(handle.getStream()));

    dbscanFit(handle, inputs, (int)params.n_row, 2, params.eps, params.min_pts,
              labels);

    CUDA_CHECK(cudaStreamSynchronize(handle.getStream()));

    score = adjustedRandIndex(handle, labels_ref, labels, (int)params.n_out);

    if (score < 1.0) {
      auto str =
        arr2Str(labels_ref, params.n_out, "labels_ref", handle.getStream());
      CUML_LOG_DEBUG("y: %s", str.c_str());
      str = arr2Str(labels, params.n_row, "labels", handle.getStream());
      CUML_LOG_DEBUG("y_hat: %s", str.c_str());
      CUML_LOG_DEBUG("Score = %lf", score);
    }
  }

  void SetUp() override { basicTest(); }

  void TearDown() override {
    CUDA_CHECK(cudaFree(labels_ref));
    CUDA_CHECK(cudaFree(labels));
    CUDA_CHECK(cudaFree(inputs));
  }

 protected:
  DBScan2DArrayInputs<T> params;
  int *labels, *labels_ref;
  T *inputs;

  double score;
};

// The input looks like a latin cross or a star with a chain:
//   .
// . . . . .
//   .
// There is 1 core-point (intersection of the bars)
// and the two points to the very right are not reachable from it
// So there should be one cluster (the plus/star on the left)
// and two noise points
const std::vector<float> test2d1_f = {0,  0, 1, 0, 1, 1, 1,
                                      -1, 2, 0, 3, 0, 4, 0};
const std::vector<double> test2d1_d(test2d1_f.begin(), test2d1_f.end());
const std::vector<int> test2d1_l = {0, 0, 0, 0, 0, -1, -1};

// The input looks like a long two-barred (orhodox) cross or
// two stars next to each other:
//   .     .
// . . . . . .
//   .     .
// There are 2 core-points but they are not reachable from each other
// So there should be two clusters, both in the form of a plus/star
const std::vector<float> test2d2_f = {0, 0, 1, 0, 1, 1, 1, -1, 2, 0,
                                      3, 0, 4, 0, 4, 1, 4, -1, 5, 0};
const std::vector<double> test2d2_d(test2d2_f.begin(), test2d2_f.end());
const std::vector<int> test2d2_l = {0, 0, 0, 0, 0, 1, 1, 1, 1, 1};

// The input looks like a two-barred (orhodox) cross or
// two stars sharing a link:
//   .   .
// . . . . .
//   .   .
// There are 2 core-points but they are not reachable from each other
// So there should be two clusters.
// However, the link that is shared between the stars
// actually has an ambiguous label (to the best of my knowledge)
// as it will depend on the order in which we process the core-points.
// Note that there are 9 input points, but only 8 labels for this reason
const std::vector<float> test2d3_f = {
  0, 0, 1, 0, 1, 1, 1, -1, 3, 0, 3, 1, 3, -1, 4, 0, 2, 0,
};
const std::vector<double> test2d3_d(test2d3_f.begin(), test2d3_f.end());
const std::vector<int> test2d3_l = {0, 0, 0, 0, 1, 1, 1, 1};

const std::vector<DBScan2DArrayInputs<float>> inputs2d_f = {
  {test2d1_f.data(), test2d1_l.data(), test2d1_f.size() / 2, test2d1_l.size(),
   1.1f, 4},
  {test2d2_f.data(), test2d2_l.data(), test2d2_f.size() / 2, test2d2_l.size(),
   1.1f, 4},
  {test2d3_f.data(), test2d3_l.data(), test2d3_f.size() / 2, test2d3_l.size(),
   1.1f, 4},
};

const std::vector<DBScan2DArrayInputs<double>> inputs2d_d = {
  {test2d1_d.data(), test2d1_l.data(), test2d1_d.size() / 2, test2d1_l.size(),
   1.1, 4},
  {test2d2_d.data(), test2d2_l.data(), test2d2_d.size() / 2, test2d2_l.size(),
   1.1, 4},
  {test2d3_d.data(), test2d3_l.data(), test2d3_d.size() / 2, test2d3_l.size(),
   1.1, 4},
};

typedef Dbscan2DSimple<float> Dbscan2DSimple_F;
TEST_P(Dbscan2DSimple_F, Result) { ASSERT_TRUE(score == 1.0); }

typedef Dbscan2DSimple<double> Dbscan2DSimple_D;
TEST_P(Dbscan2DSimple_D, Result) { ASSERT_TRUE(score == 1.0); }

INSTANTIATE_TEST_CASE_P(DbscanTests, Dbscan2DSimple_F,
                        ::testing::ValuesIn(inputs2d_f));

INSTANTIATE_TEST_CASE_P(DbscanTests, Dbscan2DSimple_D,
                        ::testing::ValuesIn(inputs2d_d));

}  // end namespace ML
