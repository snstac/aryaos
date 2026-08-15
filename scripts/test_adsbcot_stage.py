#!/usr/bin/env python3
"""Regression tests for the ADS-B pi-gen package stage."""

import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent


class AdsbCotStageTestCase(unittest.TestCase):
    def test_package_list_does_not_force_cross_suite_uuid_runtime(self):
        packages = (
            ROOT / "stages/stage-adsbcot/03-install-packages/00-packages"
        ).read_text().split()

        # A Debian Bookworm dependency source is temporarily enabled for the
        # FlightAware decoders. Explicitly requesting uuid-runtime allowed
        # Bookworm's 2.41-5 package to collide with Trixie's security-updated
        # libuuid1/libsmartcols1 2.41.5 packages. AryaOS does not use uuidgen,
        # and neither FlightAware decoder declares this dependency.
        self.assertNotIn("uuid-runtime", packages)


if __name__ == "__main__":
    unittest.main()
