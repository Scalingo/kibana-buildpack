#!/usr/bin/env bash

set -o errexit

# -----------------------------------------------------------------------------

# Update PATH
PATH="${PATH:+${PATH}:}${HOME}/kibana/bin"
export PATH

# -----------------------------------------------------------------------------

# Use Kibana's heap-sizing logic:
ELASTIC_CONTAINER='true'
export ELASTIC_CONTAINER

# -----------------------------------------------------------------------------

# Handle old env var name:
ELASTICSEARCH_SSL_VERIFICATIONMODE="${ELASTICSEARCH_SSL_VERIFICATIONMODE:-${ES_SSL_VERIFICATION_MODE:-full}}"
export ELASTICSEARCH_SSL_VERIFICATIONMODE

# -----------------------------------------------------------------------------

# Handle optional custom CA file
if [[ -n "${ELASTICSEARCH_TLS_CA_URL:-}" ]]; then
	ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES="${HOME}/kibana/ca.crt"

	curl --silent --fail --location \
		--retry 3 --retry-delay 10 --retry-connrefused \
		--connect-timeout 10 --max-time 300 \
		--output "${ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES}" -- \
		"${ELASTICSEARCH_TLS_CA_URL}"

elif [[ -n "${ELASTICSEARCH_TLS_CA_PATH:-}" ]]; then
	ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES="${HOME}/${ELASTICSEARCH_TLS_CA_PATH}"
fi

export ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES

# -----------------------------------------------------------------------------

# Split ELASTICSEARCH_URL for kibana.yml
# We use scheme://[username:password@]host[:port][/path]
if [[ -n "${ELASTICSEARCH_URL:-}" ]]; then
	# Extract the scheme (http or https).
	# '%%' removes the longest matching suffix.
	# --> Keep everything before the first ://.
	_kibana_scheme="${ELASTICSEARCH_URL%%://*}"

	# Remove the scheme from the URL.
    # '#' removes the shortest matching prefix.
	# --> Discard the scheme and its ://.
	_kibana_address="${ELASTICSEARCH_URL#*://}"

	# Isolate the credentials and host, excluding any path, query, or fragment.
    # '%%' removes the suffix starting at the first '/', '?', or '#'.
	# --> Discard a potential path, query, or fragment. Keep authority.
	_kibana_authority="${_kibana_address%%[/?#]*}"

	# Extract credentials if the URL includes them.
	if [[ "${_kibana_authority}" == *@* ]]; then
		# Separate the credentials from the host.
		# '%' removes the shortest matching suffix.
		# --> Discard the last @ and the host.
		_kibana_credentials="${_kibana_authority%@*}"
		
		# Extract the username.
		# '%%' removes the longest matching suffix.
		# --> Discard the first ':' and password.
		ELASTICSEARCH_USERNAME="${_kibana_credentials%%:*}"
		
		if [[ "${_kibana_credentials}" == *:* ]]; then
			# Extract the password.
			# '#' removes through the first ':'.
			# --> Preserve any colons in the password.
			ELASTICSEARCH_PASSWORD="${_kibana_credentials#*:}"
		fi

		# Remove credentials from the address.
		# '#' removes the credentials plus @ prefix.
		# The quoted expansion is matched literally.
		_kibana_address="${_kibana_address#"${_kibana_credentials}@"}"
	fi

	# Rebuild the Elasticsearch URL without credentials.
	ELASTICSEARCH_HOST="${_kibana_scheme}://${_kibana_address}"

	export ELASTICSEARCH_USERNAME
	export ELASTICSEARCH_PASSWORD
	export ELASTICSEARCH_HOST

	unset \
		_kibana_scheme \
		_kibana_address \
		_kibana_authority \
		_kibana_credentials
fi
