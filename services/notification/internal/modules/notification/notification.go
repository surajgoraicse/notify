package notification

import "context"

type INotificationService interface {
	Send(ctx context.Context, req *SendRequest) (*Notification, error)
	SendBulk(ctx context.Context, req []SendRequest) ([]Notification, error)
}
