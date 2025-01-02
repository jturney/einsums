//--------------------------------------------------------------------------------------------
// Copyright (c) The Einsums Developers. All rights reserved.
// Licensed under the MIT License. See LICENSE.txt in the project root for license information.
//--------------------------------------------------------------------------------------------

#include <Einsums/Config.hpp>

#include <Einsums/Assert.hpp>
#include <Einsums/BLAS.hpp>
#include <Einsums/Errors/Error.hpp>
#include <Einsums/Errors/ThrowException.hpp>
#include <Einsums/Logging.hpp>
#include <Einsums/Profile/Timer.hpp>
#include <Einsums/Runtime/Detail/InitLogging.hpp>
#include <Einsums/Runtime/InitRuntime.hpp>
#include <Einsums/Runtime/Runtime.hpp>
#include <Einsums/Utilities/Random.hpp>

#ifdef EINSUMS_COMPUTE_CODE
#    include <Einsums/GPUStreams/GPUStreams.hpp>
#endif

#include <csignal>
#include <cstdlib>
#include <functional>
#include <h5cpp/all>
#include <spdlog/spdlog.h>
#include <tuple>
#include <unordered_map>

namespace einsums {

template <typename F, typename... BoundArgs>
struct bind_back_t {
    F                        func_;
    std::tuple<BoundArgs...> bound_args_;

    template <typename... CallArgs, std::size_t... Indices>
    auto invoke_impl(std::index_sequence<Indices...>, CallArgs &&...call_args) const {
        return func_(std::forward<CallArgs>(call_args)..., std::get<Indices>(bound_args_)...);
    }

    template <typename... CallArgs, std::size_t... Indices>
    auto invoke_impl(std::index_sequence<Indices...>, CallArgs &&...call_args) {
        return func_(std::forward<CallArgs>(call_args)..., std::get<Indices>(bound_args_)...);
    }

    template <typename Func, typename... Args>
    bind_back_t(Func &&func, Args &&...args) : func_(std::forward<Func>(func)), bound_args_(std::forward<Args>(args)...) {}

    template <typename... CallArgs>
    auto operator()(CallArgs &&...call_args) const {
        return invoke_impl(std::index_sequence_for<BoundArgs...>{}, std::forward<CallArgs>(call_args)...);
    }

    template <typename... CallArgs>
    auto operator()(CallArgs &&...call_args) {
        return invoke_impl(std::index_sequence_for<BoundArgs...>{}, std::forward<CallArgs>(call_args)...);
    }
};

template <typename F, typename... BoundArgs>
auto bind_back(F &&func, BoundArgs &&...bound_args) {
    return bind_back_t<std::decay_t<F>, std::decay_t<BoundArgs>...>(std::forward<F>(func), std::forward<BoundArgs>(bound_args)...);
}

namespace detail {

void add_startup_functions(Runtime &rt, RuntimeConfiguration const &cfg, StartupFunctionType startup, ShutdownFunctionType shutdown) {
    if (!!startup) {
        rt.add_startup_function(std::move(startup));
    }

    if (!!shutdown) {
        rt.add_shutdown_function(std::move(shutdown));
    }
}

int run(std::function<int(RuntimeConfiguration const &map)> const &f, Runtime &rt, RuntimeConfiguration const &cfg,
        InitParams const &params) {
    add_startup_functions(rt, cfg, std::move(params.startup), std::move(params.shutdown));

    // Run this runtime instance using the given function f
    if (f) {
        return rt.run(std::bind_front(f, cfg));
    }

    // Run this runtime instance without an einsums_main
    return rt.run();
}

int run(std::function<int(RuntimeConfiguration const &map)> const &f, int argc, char const *const *argv, InitParams const &params,
        bool blocking) {
    // TODO: Add a check to ensure the runtime hasn't already been initialized

    // TODO: Translate argv to unordered_map.
    // Command line arguments for Einsums will be prefixed with --einsums:
    // For example, "--einsums:verbose=1" will be translated to verbose=1
    std::unordered_map<std::string, std::string> cmdline;
    RuntimeConfiguration                         config(argc, argv);

    if (config.einsums.install_signal_handlers) {
        set_signal_handlers();
    }

    init_logging(config);

    // This might be a good place to initialize MPI, HIP, CUDA, etc.
    // error::initialize();

#if defined(EINSUMS_COMPUTE_CODE)
    gpu::initialize();
#endif

    profile::initialize();
    blas::initialize();

    // Disable HDF5 diagnostic reporting
    H5Eset_auto(0, nullptr, nullptr);

    einsums::random_engine = std::default_random_engine(std::chrono::system_clock::now().time_since_epoch().count());

    // TODO: Build and configure a runtime instance
    // Using cmdline, call a function to parse and translate all known command line options into a GlobalConfigMap

    // Build and configure this runtime instance.
    std::unique_ptr<Runtime> rt;

    rt.reset(new Runtime(config, true));

    if (blocking) {
        return run(f, *rt, config, params);
    }

    run(f, *rt, config, params);

    // pointer to runtime is stored in TLS
    [[maybe_unused]] Runtime *p = rt.release();

    return 0;
}

int run_impl(std::function<int(RuntimeConfiguration const &)> f, int argc, char const *const *argv, InitParams const &params,
             bool blocking) {
    if (argc == 0 || argv == nullptr) {
        argc = dummy_argc;
        argv = dummy_argv;
    }

    // register default handlers
    [[maybe_unused]] auto signal_handler = std::signal(SIGABRT, on_abort);
    [[maybe_unused]] auto exit_result    = std::atexit(on_exit);
#if defined(EINSUMS_HAVE_CXX11_STD_QUICK_EXIT)
    [[maybe_unused]] auto quick_exit_result = std::at_quick_exit(on_exit);
#endif
    return run(f, argc, argv, params, blocking);
}

} // namespace detail

int initialize(std::function<int(RuntimeConfiguration const &)> f, int argc, char **argv, InitParams const &params) {
    return detail::run_impl(std::move(f), argc, argv, params, true);
}

int initialize(std::function<int(int, char **)> f, int argc, char **argv, InitParams const &params) {
    std::function<int(RuntimeConfiguration const &)> main_f = std::bind(f, argc, argv);
    return detail::run_impl(std::move(main_f), argc, argv, params, true);
}

int initialize(std::function<int()> f, int argc, char **argv, InitParams const &params) {
    std::function<int(RuntimeConfiguration const &)> main_f = std::bind(f);
    return detail::run_impl(std::move(main_f), argc, argv, params, true);
}

int initialize(std::nullptr_t, int argc, char **argv, InitParams const &params) {
    std::function<int(RuntimeConfiguration const &)> main_f;
    return detail::run_impl(std::move(main_f), argc, argv, params, true);
}

void start(std::function<int()> f, int argc, char const *const *argv, InitParams const &params) {
    std::function<int(RuntimeConfiguration const &)> main_f = std::bind(f);
    if (detail::run_impl(std::move(main_f), argc, argv, params, false) != 0) {
        EINSUMS_UNREACHABLE;
    }
}

void start(std::nullptr_t, int argc, char const *const *argv, InitParams const &params) {
    std::function<int(RuntimeConfiguration const &)> main_f;
    if (detail::run_impl(std::move(main_f), argc, argv, params, false) != 0) {
        EINSUMS_UNREACHABLE;
    }
}

void start(int argc, char const *const *argv, InitParams const &params) {
    std::function<int(RuntimeConfiguration const &)> main_f;
    if (detail::run_impl(std::move(main_f), argc, argv, params, false) != 0) {
        EINSUMS_UNREACHABLE;
    }
}

void finalize() {
    auto &rt = detail::runtime();
    rt.call_shutdown_functions(true);
    EINSUMS_LOG(info, "ran pre-shutdown functions");
    rt.call_shutdown_functions(false);
    EINSUMS_LOG(info, "ran shutdown functions");
    rt.deinit_global_data();

    // Finalize everything
    blas::finalize();

    // TODO: If we are generating a timing report do it here before profile::finalize().

    profile::finalize();

#if defined(EINSUMS_COMPUTE_CODE)
    gpu::finalize();
#endif
}

} // namespace einsums