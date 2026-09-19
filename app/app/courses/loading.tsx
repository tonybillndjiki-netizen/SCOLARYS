export default function CoursesLoading() {
  return (
    <div aria-busy="true" aria-label="Chargement des cours">
      <div className="h-6 w-28 animate-pulse rounded-full bg-[#e5eaf0]" />
      <div className="mt-4 h-10 w-64 animate-pulse rounded-xl bg-[#e5eaf0]" />
      <div className="surface mt-7 h-56 animate-pulse bg-white/60" />
      <div className="mt-7 grid gap-5 lg:grid-cols-2 2xl:grid-cols-3">
        {[0, 1, 2, 3, 4, 5].map((item) => (
          <div key={item} className="surface h-72 animate-pulse bg-white/60" />
        ))}
      </div>
    </div>
  );
}
