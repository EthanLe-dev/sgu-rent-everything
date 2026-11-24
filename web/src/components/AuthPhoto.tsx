'use client';

import React, { useEffect, useState } from 'react';
import { api, STITCH_FALLBACK_PHOTOS } from '@/lib/api';

interface AuthPhotoProps {
  photoIds?: string[];
  fallbackKey?: string;
  alt: string;
  className?: string;
}

export function AuthPhoto({
  photoIds,
  fallbackKey = 'default',
  alt,
  className = 'w-full h-full object-cover',
}: AuthPhotoProps) {
  const firstId = photoIds && photoIds.length > 0 ? photoIds[0] : null;
  const fallbackSrc =
    STITCH_FALLBACK_PHOTOS[fallbackKey] || STITCH_FALLBACK_PHOTOS.default;
  const [blobUrl, setBlobUrl] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    let currentUrl: string | null = null;

    if (!firstId) {
      setBlobUrl(null);
      return;
    }

    if (firstId.startsWith('http://') || firstId.startsWith('https://')) {
      setBlobUrl(firstId);
      return;
    }

    api.fetchPhotoObjectUrl(firstId).then((url) => {
      if (!active) {
        if (url) URL.revokeObjectURL(url);
        return;
      }
      currentUrl = url;
      setBlobUrl(url);
    });

    return () => {
      active = false;
      if (currentUrl) URL.revokeObjectURL(currentUrl);
    };
  }, [firstId]);

  return <img src={blobUrl || fallbackSrc} alt={alt} className={className} />;
}
