# SCOLARYS

**Toute votre pédagogie. Un seul environnement.**

SCOLARYS est une plateforme SaaS multi-tenant de pilotage pédagogique destinée aux écoles supérieures, universités, CFA, centres et organismes de formation.

## Stack

- Next.js App Router
- React + TypeScript
- Tailwind CSS
- Supabase (PostgreSQL, Auth, RLS, Storage)
- Netlify

## Principes

- Isolation stricte des données par organisation
- RBAC et permissions personnalisables
- Aucun faux bouton : chaque action fonctionne ou affiche explicitement « Configuration requise »
- IA : l'IA propose, l'enseignant valide
- Responsive mobile / tablette / desktop
- Architecture configurable pour établissements mono ou multi-campus

## État

Le dépôt accueille désormais la nouvelle base applicative SCOLARYS. Le développement suit les phases Foundation, School Management, LMS, Assessment, Academic Management, Projects, AI, Communication, Integrations, Analytics et Commercial.

### Phase 3 · LMS

Le premier incrément fonctionnel couvre désormais :

- la liste des cours avec recherche, filtres et pagination ;
- la création et la modification transactionnelles d’un cours ;
- la page de détail selon les droits de l’utilisateur ;
- le Studio de cours avec création, édition, publication, suppression et réordonnancement des chapitres ;
- le durcissement RLS, des privilèges Data API et de l’intégrité multi-tenant des tables LMS.

La bibliothèque de ressources, les séances et l’éditeur de chapitre par blocs constituent les incréments LMS suivants.
