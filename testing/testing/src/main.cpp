//--------------------------------------------------------------------------------------------
// Copyright (c) The Einsums Developers. All Rights Reserved.
// Licensed under the MIT License. See LICENSE.txt in the project root for license information.
//--------------------------------------------------------------------------------------------

#include <Einsums/Runtime.hpp>
#include <Einsums/Utilities/Random.hpp>

#include <functional>

#include "catch2/catch_get_random_seed.hpp"

#define CATCH_CONFIG_RUNNER
#include <catch2/catch_all.hpp>

int einsums_main(int argc, char **argv) {
    Catch::Session session;
    session.applyCommandLine(argc, argv);

    // This is crashing.
    // einsums::seed_random(Catch::getSeed());

    int result = session.run();
    einsums::finalize();

    return result;
}

int main(int argc, char **argv) {
    Catch::StringMaker<float>::precision  = std::numeric_limits<float>::digits10;
    Catch::StringMaker<double>::precision = std::numeric_limits<double>::digits10;

    // auto const wrapped = std::bind_front(&einsums_main, argc, argv);

    return einsums::initialize(einsums_main, argc, argv);
}
