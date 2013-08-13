#!/bin/pythonusername="admin@internal",

import sys

from ovirtsdk.api import API
from ovirtsdk.xml import params

if len(sys.argv) < 2:
    print """ERROR: UPN required.
Usage:
    python add_user <user@domain>"""
    sys.exit(1)

# Save UPN to a variable and extract domain.
input_upn=sys.argv[1]
input_user=input_upn.split("@")[0]
input_domain=input_upn.split("@")[1]

try:

    # Connect to API hosted on local host.
    api = API (url="https://127.0.0.1:8443",
               username="admin@internal",
               password="PASSWORD",
               ca_file="/var/lib/jbossas/server/rhevm-slimmed/deploy/ROOT.war/ca.crt")

    user_search = api.users.list(user_name=input_upn)

    # Check for existing user with given UPN.
    if len(user_search) > 0:
        print "INFO: User %s already exists." % input_upn
        sys.exit(0)
    else:
        # Add the specified user.
        user_params = params.User(user_name=input_user, domain=api.domains.get(name=input_domain))
        output_user = api.users.add(user_params)
        print "INFO: User %s added to RHEV." % input_upn

    api.disconnect()

except Exception as ex:
    print "ERROR: Unexpected error: %s" % ex
    sys.exit(1)
