import { PageHeader } from '@/components/layout/PageHeader'
import { buttonVariants } from '@/components/ui/button'
import { Card, CardBody } from '@/components/ui/card'

/** Pages that are not moved to the new Studio yet. */
export function Soon({ title, what, classic }: { title: string; what: string; classic?: { href: string; label: string } }) {
  return (
    <div className="max-w-[760px]">
      <PageHeader title={title} />
      <Card>
        <CardBody className="flex flex-col items-start gap-3">
          <div className="text-[15px] font-semibold">Coming to the new Studio</div>
          <div className="text-muted">{what}</div>
          {classic && <a href={classic.href} className={buttonVariants({ variant: 'outline' })}>{classic.label}</a>}
        </CardBody>
      </Card>
    </div>
  )
}
