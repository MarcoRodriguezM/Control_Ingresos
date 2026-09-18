const iconPaths = {
  logo: <><path d="M7 5.5h10M7 12h8M7 18.5h10" /><path d="M5 3h14v18H5z" /></>,
  home: <><path d="M3 11.5 12 4l9 7.5" /><path d="M5.5 10.5V20h13v-9.5M9.5 20v-6h5v6" /></>,
  file: <><path d="M6 3h8l4 4v14H6z" /><path d="M14 3v5h5M9 12h6M9 16h6" /></>,
  check: <path d="m5 12 4 4L19 6" />,
  tasks: <><rect x="5" y="4" width="14" height="16" rx="2" /><path d="M9 9h6M9 13h6M9 17h4" /></>,
  users: <><circle cx="9" cy="7" r="4" /><path d="M2 21v-2a4 4 0 0 1 4-4h6a4 4 0 0 1 4 4v2M17 4a4 4 0 0 1 0 7" /></>,
  settings: <><circle cx="12" cy="12" r="3" /><path d="M19 12a7 7 0 1 1-14 0 7 7 0 0 1 14 0M12 3V1M12 23v-2M21 12h2M1 12h2" /></>,
  menu: <path d="M4 6h16M4 12h16M4 18h16" />,
  bell: <path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4" />,
  help: <><circle cx="12" cy="12" r="9" /><path d="M9.7 9a2.5 2.5 0 1 1 3.4 2.3c-.7.3-1.1.9-1.1 1.7v.5M12 17h.01" /></>,
  search: <><circle cx="11" cy="11" r="7" /><path d="m20 20-4-4" /></>,
  shield: <><path d="M12 3 5 6v5c0 4.8 2.8 8.1 7 10 4.2-1.9 7-5.2 7-10V6z" /><path d="m9 12 2 2 4-4" /></>,
  arrow: <path d="M5 12h14M14 7l5 5-5 5" />,
  back: <path d="M19 12H5M10 17l-5-5 5-5" />,
  send: <path d="m22 2-7 20-4-9-9-4zM22 2 11 13" />,
  logout: <path d="M10 17l5-5-5-5M15 12H3M15 4h5v16h-5" />,
  user: <><circle cx="12" cy="8" r="4" /><path d="M4 21a8 8 0 0 1 16 0" /></>,
  lock: <><rect x="5" y="10" width="14" height="11" rx="2" /><path d="M8 10V7a4 4 0 0 1 8 0v3M12 14v3" /></>,
  warning: <><path d="M12 3 2.8 19h18.4z" /><path d="M12 9v4M12 17h.01" /></>,
}

export function Icon({ name }) {
  return <svg className="icon-svg" viewBox="0 0 24 24" aria-hidden="true">{iconPaths[name] ?? iconPaths.file}</svg>
}
