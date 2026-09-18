
    update public.scolaria_organizations
    set
      name = 'SCOLARYS Demo School',
      legal_name = 'SCOLARYS Demo School',
      email = 'demo@scolarys.app',
      updated_at = now()
    where slug = 'edulink-demo-school';
  
