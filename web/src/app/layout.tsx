import type { Metadata, Viewport } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Thuê Đồ Sinh Viên — Đại học Sài Gòn',
  description:
    'Nền tảng thuê và cho thuê đồ sinh viên Đại học Sài Gòn tại Cơ sở 1, Cơ sở 2 và Cơ sở Chính.',
  manifest: '/manifest.json',
  appleWebApp: {
    capable: true,
    statusBarStyle: 'default',
    title: 'Thuê Đồ Sinh Viên',
  },
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 5,
  viewportFit: 'cover',
  themeColor: '#0A0435',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="vi" data-type="software">
      <head>
        <meta name="page-type" content="software" />
        <meta name="site-kind" content="software" />
        <link
          href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&family=Source+Code+Pro:wght@500;600&display=swap"
          rel="stylesheet"
        />
        <link
          href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&display=block"
          rel="stylesheet"
        />
      </head>
      <body className="bg-light-surface text-light-on-surface font-body antialiased min-h-screen">
        {children}
      </body>
    </html>
  );
}
