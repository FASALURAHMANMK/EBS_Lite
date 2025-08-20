import Link from 'next/link';

export default function SettingsHome() {
  return (
    <div className="p-4">
      <h1 className="text-2xl font-bold mb-4">Settings</h1>
      <ul className="list-disc pl-5 space-y-1">
        <li><Link href="/settings/company">Company</Link></li>
        <li><Link href="/settings/locations">Locations</Link></li>
        <li><Link href="/settings/users">Users</Link></li>
        <li><Link href="/settings/devices">Devices</Link></li>
        <li><Link href="/settings/backup">Backup</Link></li>
        <li><Link href="/settings/integrations">Integrations</Link></li>
        <li><Link href="/settings/pos">POS &amp; Printer Setup</Link></li>
      </ul>
    </div>
  );
}
