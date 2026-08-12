#!/usr/bin/env bash
/usr/lib/mate-polkit/polkit-mate-authentication-agent-1 || \
/run/current-system/sw/libexec/polkit-mate-authentication-agent-1 || \
/usr/libexec/polkit-mate-authentication-agent-1