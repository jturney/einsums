//----------------------------------------------------------------------------------------------
// Copyright (c) The Einsums Developers. All rights reserved.
// Licensed under the MIT License. See LICENSE.txt in the project root for license information.
//----------------------------------------------------------------------------------------------

#pragma once

#include <einsums/config.hpp>

#include <cstddef>
#include <cstdint>
#include <limits>

///////////////////////////////////////////////////////////////////////////////
namespace einsums::threads::detail {
struct thread_queue_init_parameters {
    // NOLINTBEGIN(bugprone-easily-swappable-parameters)
    thread_queue_init_parameters(std::int64_t   max_thread_count           = std::int64_t(EINSUMS_THREAD_QUEUE_MAX_THREAD_COUNT),
                                 std::int64_t   min_tasks_to_steal_pending = std::int64_t(EINSUMS_THREAD_QUEUE_MIN_TASKS_TO_STEAL_PENDING),
                                 std::int64_t   min_tasks_to_steal_staged  = std::int64_t(EINSUMS_THREAD_QUEUE_MIN_TASKS_TO_STEAL_STAGED),
                                 std::int64_t   min_add_new_count          = std::int64_t(EINSUMS_THREAD_QUEUE_MIN_ADD_NEW_COUNT),
                                 std::int64_t   max_add_new_count          = std::int64_t(EINSUMS_THREAD_QUEUE_MAX_ADD_NEW_COUNT),
                                 std::int64_t   min_delete_count           = std::int64_t(EINSUMS_THREAD_QUEUE_MIN_DELETE_COUNT),
                                 std::int64_t   max_delete_count           = std::int64_t(EINSUMS_THREAD_QUEUE_MAX_DELETE_COUNT),
                                 std::int64_t   max_terminated_threads     = std::int64_t(EINSUMS_THREAD_QUEUE_MAX_TERMINATED_THREADS),
                                 std::int64_t   init_threads_count         = std::int64_t(EINSUMS_THREAD_QUEUE_INIT_THREADS_COUNT),
                                 double         max_idle_backoff_time      = double(EINSUMS_IDLE_BACKOFF_TIME_MAX),
                                 std::ptrdiff_t small_stacksize            = EINSUMS_SMALL_STACK_SIZE,
                                 std::ptrdiff_t medium_stacksize           = EINSUMS_MEDIUM_STACK_SIZE,
                                 std::ptrdiff_t large_stacksize            = EINSUMS_LARGE_STACK_SIZE,
                                 std::ptrdiff_t huge_stacksize             = EINSUMS_HUGE_STACK_SIZE)
        // NOLINTEND(bugprone-easily-swappable-parameters)
        : max_thread_count_(max_thread_count), min_tasks_to_steal_pending_(min_tasks_to_steal_pending),
          min_tasks_to_steal_staged_(min_tasks_to_steal_staged), min_add_new_count_(min_add_new_count),
          max_add_new_count_(max_add_new_count), min_delete_count_(min_delete_count), max_delete_count_(max_delete_count),
          max_terminated_threads_(max_terminated_threads), init_threads_count_(init_threads_count),
          max_idle_backoff_time_(max_idle_backoff_time), small_stacksize_(small_stacksize), medium_stacksize_(medium_stacksize),
          large_stacksize_(large_stacksize), huge_stacksize_(huge_stacksize),
          nostack_stacksize_((std::numeric_limits<std::ptrdiff_t>::max)()) {}

    std::int64_t         max_thread_count_;
    std::int64_t         min_tasks_to_steal_pending_;
    std::int64_t         min_tasks_to_steal_staged_;
    std::int64_t         min_add_new_count_;
    std::int64_t         max_add_new_count_;
    std::int64_t         min_delete_count_;
    std::int64_t         max_delete_count_;
    std::int64_t         max_terminated_threads_;
    std::int64_t         init_threads_count_;
    double               max_idle_backoff_time_;
    std::ptrdiff_t const small_stacksize_;
    std::ptrdiff_t const medium_stacksize_;
    std::ptrdiff_t const large_stacksize_;
    std::ptrdiff_t const huge_stacksize_;
    std::ptrdiff_t const nostack_stacksize_;
};
} // namespace einsums::threads::detail
