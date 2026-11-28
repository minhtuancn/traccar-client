package org.traccar.client

import androidx.core.content.FileProvider

/** Exposes only the verified-update cache subdirectory, with temporary URI grants. */
class UpdateFileProvider : FileProvider()
