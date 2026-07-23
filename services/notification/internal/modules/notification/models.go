package notification

import (
	"time"
)

type Priority string

const (
	PriorityHigh   Priority = "high"
	PriorityMedium Priority = "medium"
	PriorityLow    Priority = "low"
)

func (p Priority) IsValid() bool {
	switch p {
	case PriorityHigh, PriorityMedium, PriorityLow:
		return true
	default:
		return false
	}
}

func (p Priority) String() string {
	return string(p)
}

type Channel string

const (
	ChannelEmail Channel = "email"
	ChannelSMS   Channel = "sms"
	ChannelPush  Channel = "push"
)

func (c Channel) IsValid() bool {
	switch c {
	case ChannelEmail, ChannelSMS, ChannelPush:
		return true
	default:
		return false
	}
}

func (c Channel) String() string {
	return string(c)
}

type Status string

const (
	StatusPending    Status = "pending"
	StatusQueued     Status = "queued"
	StatusProcessing Status = "processing"
	StatusSent       Status = "sent"
	StatusDelivered  Status = "delivered"
	StatusFailed     Status = "failed"
	StatusCancelled  Status = "cancelled"
)

func (s Status) IsValid() bool {
	switch s {
	case StatusPending, StatusQueued, StatusProcessing, StatusSent, StatusDelivered, StatusFailed, StatusCancelled:
		return true
	default:
		return false
	}
}

func (s Status) String() string {
	return string(s)
}

type SendRequest struct {
	AppID       string
	UserID      string
	Channel     []Channel
	TemplateID  string
	Priority    Priority
	Title       string
	Body        string
	Data        map[string]any
	ScheduledAt *time.Time
	Metadata    map[string]any
	// Recurrence  Recurrence
	// WorkflowTriggerID string // triggers workflow after send
}

type Notification struct {
	ID           string      `json:"id"`
	AppID        string      `json:"app_id"`
	Req          SendRequest `json:"req"`
	Status       Status      `json:"status"`
	SendAt       *time.Time  `json:"send_at"`
	DeliveryAt   *time.Time  `json:"delivery_at,omitempty"`
	FailedAt     *time.Time  `json:"failed_at,omitempty"`
	ErrorMessage string      `json:"error_message,omitempty"`
	RetryCount   int         `json:"retry_count"`
	CreatedAt    *time.Time  `json:"created_at"`
	UpdatedAt    *time.Time  `json:"updated_at"`
}
