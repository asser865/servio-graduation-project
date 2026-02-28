import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Servio Frontend',
  description: 'AI-powered home maintenance and finishing services platform',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
