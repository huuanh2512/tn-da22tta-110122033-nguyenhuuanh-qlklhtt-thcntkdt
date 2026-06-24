import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { Card, Form, Select, TimePicker, Button, Alert, message, Typography, Divider, Space, Row, Col } from 'antd';
import { CheckCircleOutlined, CloseCircleOutlined, SaveOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';
import { authStorage } from '../../../../core/utils/auth_storage';
import { apiClient } from '../../../../core/network/api_client';
import { minutesToTimeStr } from '../../../../core/utils/formatters';

const { Title, Text } = Typography;

interface CourtItem {
  _id: string;
  name: string;
  code: string;
  facilityId: string;
  status: string;
  pricePerHour: number;
  sportId?: string;
  sport?: { id?: string; _id?: string; name?: string };
  sportName?: string;
}

interface SportItem {
  _id: string;
  id?: string;
  name: string;
}

const getRefId = (value: any): string => {
  if (!value) return '';
  if (typeof value === 'string') return value;
  return value.id || value._id || '';
};

const StaffSlotsPage: React.FC = () => {
  const user = useMemo(() => authStorage.getUser(), []);
  const [courts, setCourts] = useState<CourtItem[]>([]);
  const [selectedCourtId, setSelectedCourtId] = useState<string>('');
  const [form] = Form.useForm();
  
  // Slot configuration preview states
  const [openingTime, setOpeningTime] = useState<dayjs.Dayjs>(dayjs('06:00', 'HH:mm'));
  const [closingTime, setClosingTime] = useState<dayjs.Dayjs>(dayjs('22:00', 'HH:mm'));
  const [slotDuration, setSlotDuration] = useState<number>(60);
  const [previewSlots, setPreviewSlots] = useState<any[]>([]);
  const [validationError, setValidationError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  // Load facility courts from API
  const loadCourts = useCallback(async () => {
    if (!user?.facilityId) return;
    try {
      const [resCourts, resSports] = await Promise.all([
        apiClient.get('/court', { params: { facilityId: user.facilityId } }),
        apiClient.get('/sport'),
      ]);
      const sports: SportItem[] = (resSports.data.items || []).map((sport: any) => ({
        ...sport,
        _id: sport.id || sport._id || '',
      }));
      const courtItems: CourtItem[] = (resCourts.data.items || [])
        .filter((c: any) => c.status === 'ACTIVE')
        .map((c: any) => {
          const sportId = c.sportId || c.sport_id || getRefId(c.sport);
          const sport = sports.find(item => item._id === sportId || item.id === sportId);
          return {
            ...c,
            _id: c._id || c.id || '',
            sportId,
            sportName: c.sport?.name || sport?.name || 'Chưa gán môn',
          };
        });
      setCourts(courtItems);
      if (courtItems.length > 0) {
        setSelectedCourtId(prev => prev || courtItems[0]._id);
      }
    } catch {
      message.error('Không thể tải danh sách sân');
    }
  }, [user]);

  useEffect(() => {
    loadCourts();
  }, [loadCourts]);

  // Load configured slots when court selection changes (from real API)
  useEffect(() => {
    if (!selectedCourtId) return;
    apiClient.get(`/court/${selectedCourtId}/slot-config`).then(res => {
      const config = res.data.config;
      if (config) {
        const openTime = dayjs(minutesToTimeStr(config.openingMinutes), 'HH:mm');
        const closeTime = dayjs(minutesToTimeStr(config.closingMinutes), 'HH:mm');
        form.setFieldsValue({
          courtId: selectedCourtId,
          openingTime: openTime,
          closingTime: closeTime,
          slotDuration: config.slotDurationMinutes
        });
        setOpeningTime(openTime);
        setClosingTime(closeTime);
        setSlotDuration(config.slotDurationMinutes);
        const rawSlots = config.slots || [];
        const mappedSlots = rawSlots.map((s: any, idx: number) => ({
          slotIndex: s.slotIndex || idx + 1,
          startMinutes: s.startMinutes,
          endMinutes: s.endMinutes,
          isAvailable: s.mode === 'AVAILABLE' || s.isAvailable || false,
        }));
        setPreviewSlots(mappedSlots);
      } else {
        // No config yet — set defaults
        const openTime = dayjs('07:00', 'HH:mm');
        const closeTime = dayjs('22:00', 'HH:mm');
        form.setFieldsValue({ courtId: selectedCourtId, openingTime: openTime, closingTime: closeTime, slotDuration: 60 });
        setOpeningTime(openTime);
        setClosingTime(closeTime);
        setSlotDuration(60);
        setPreviewSlots([]);
      }
    }).catch(() => {
      setPreviewSlots([]);
    });
  }, [selectedCourtId, form]);

  // Regenerate slot previews dynamically
  const generatePreview = (open: dayjs.Dayjs, close: dayjs.Dayjs, duration: number, keepAvailability: boolean = true) => {
    setValidationError(null);

    const openMin = open.hour() * 60 + open.minute();
    const closeMin = close.hour() * 60 + close.minute();
    const totalMinutes = closeMin - openMin;

    // 1. Validation: Closing time must be after opening time
    if (closeMin <= openMin) {
      setValidationError('Giờ đóng cửa bắt buộc phải sau giờ mở cửa.');
      setPreviewSlots([]);
      return;
    }

    // 2. Validation: Total minutes >= 120 (2 hours)
    if (totalMinutes < 120) {
      setValidationError('Tổng thời gian vận hành tối thiểu phải đạt 120 phút (2 tiếng).');
      setPreviewSlots([]);
      return;
    }

    // 3. Validation: Total minutes divisible by slot duration
    if (totalMinutes % duration !== 0) {
      setValidationError(
        `Tổng số phút vận hành (${totalMinutes} phút) phải chia hết cho Độ dài 1 ca (${duration} phút). ` +
        `Hiện tại đang dư ${totalMinutes % duration} phút.`
      );
      setPreviewSlots([]);
      return;
    }

    // Generate new preview slots
    const slots = [];
    let index = 1;
    for (let min = openMin; min + duration <= closeMin; min += duration) {
      // Look for existing availability if keeping states
      const existingSlot = keepAvailability 
        ? previewSlots.find(s => s.startMinutes === min && s.endMinutes === min + duration)
        : null;

      slots.push({
        slotIndex: index++,
        startMinutes: min,
        endMinutes: min + duration,
        isAvailable: existingSlot ? existingSlot.isAvailable : true
      });
    }
    setPreviewSlots(slots);
  };

  // Trigger preview generation on fields change
  const handleValuesChange = (changedValues: any, allValues: any) => {
    const open = allValues.openingTime;
    const close = allValues.closingTime;
    const duration = allValues.slotDuration;

    if (open && close && duration) {
      setOpeningTime(open);
      setClosingTime(close);
      setSlotDuration(duration);
      
      // If duration changed, reset all availability to true (since slots range completely change)
      const isDurationChanged = 'slotDuration' in changedValues;
      generatePreview(open, close, duration, !isDurationChanged);
    }
  };

  // Toggle single slot availability in preview
  const handleToggleSlot = (slotIndex: number) => {
    const updated = previewSlots.map(s => {
      if (s.slotIndex === slotIndex) {
        return { ...s, isAvailable: !s.isAvailable };
      }
      return s;
    });
    setPreviewSlots(updated);
  };

  // Save config via API
  const handleSaveConfig = async () => {
    if (validationError || previewSlots.length === 0) {
      message.error('Vui lòng kiểm tra lại cấu hình thời gian hợp lệ!');
      return;
    }

    setSaving(true);
    try {
      const openMin = openingTime.hour() * 60 + openingTime.minute();
      const closeMin = closingTime.hour() * 60 + closingTime.minute();

      const mappedSlotsForApi = previewSlots.map((s: any) => ({
        slotIndex: s.slotIndex,
        startMinutes: s.startMinutes,
        endMinutes: s.endMinutes,
        mode: s.isAvailable ? 'AVAILABLE' : 'UNAVAILABLE'
      }));

      await apiClient.put(`/court/${selectedCourtId}/slot-config`, {
        openingMinutes: openMin,
        closingMinutes: closeMin,
        slotDurationMinutes: slotDuration,
        slots: mappedSlotsForApi
      });
      message.success('Cập nhật cấu hình khung giờ sân thành công!');
      
      // Update local courts list state
      const updatedCourts = courts.map(c => {
        if (c._id === selectedCourtId) {
          return {
            ...c,
            openingMinutes: openMin,
            closingMinutes: closeMin,
            slotDurationMinutes: slotDuration,
            slots: previewSlots
          };
        }
        return c;
      });
      setCourts(updatedCourts);
    } catch (e: any) {
      message.error('Cấu hình thất bại');
    } finally {
      setSaving(false);
    }
  };

  if (user && user.role === 'STAFF' && !user.facilityId) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[400px] text-center p-6 bg-white dark:bg-surface-dark1 rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 shadow-sm">
        <div className="text-brand-orange text-5xl mb-4">⚠️</div>
        <Title level={4} className="m-0 dark:text-white" style={{ fontWeight: 600 }}>
          Chưa được gán Cơ sở hoạt động
        </Title>
        <Text className="text-ink-muted dark:text-ink-darkMuted mt-2 max-w-md block">
          Tài khoản Nhân viên của bạn chưa được liên kết với cơ sở thể thao nào. Vui lòng liên hệ với Quản trị viên hệ thống để gán cơ sở trước khi thực hiện các nghiệp vụ quản lý.
        </Text>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Title */}
      <div className="border-b border-semantic-border/10 dark:border-semantic-borderDark/10 pb-4">
        <Title level={3} className="m-0 dark:text-white" style={{ fontWeight: 700 }}>
          Cấu hình Khung giờ Sân (Court Slots)
        </Title>
        <Text className="text-ink-muted dark:text-ink-darkMuted">
          Thiết lập giờ mở/đóng cửa, phân bổ độ dài 1 ca đấu và bật/tắt trạng thái hoạt động từng ca.
        </Text>
      </div>

      {courts.length === 0 ? (
        <Alert
          message="Không tìm thấy sân hoạt động"
          description="Cơ sở của bạn hiện chưa có sân đấu nào được kích hoạt để cấu hình."
          type="warning"
          showIcon
        />
      ) : (
        <Row gutter={[24, 24]}>
          {/* Left panel: configurations form */}
          <Col xs={24} md={8}>
            <Card className="rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 bg-white dark:bg-surface-dark1 shadow-sm">
              <Form
                form={form}
                layout="vertical"
                onValuesChange={handleValuesChange}
              >
                <Form.Item
                  name="courtId"
                  label={<span className="font-semibold dark:text-white">Chọn sân đấu</span>}
                  rules={[{ required: true }]}
                >
                  <Select
                    onChange={setSelectedCourtId}
                    className="rounded-md"
                    showSearch
                    optionFilterProp="label"
                    optionLabelProp="label"
                  >
                    {courts.map(c => (
                      <Select.Option
                        key={c._id}
                        value={c._id}
                        label={`${c.name} - ${c.sportName || 'Chưa gán môn'}`}
                        title={c.sportName || 'Chưa gán môn'}
                      >
                        <div className="flex flex-col leading-tight py-1">
                          <span className="font-semibold">{c.name}</span>
                          <span className="text-xs text-ink-muted dark:text-ink-darkMuted">{c.sportName || 'Chưa gán môn'}</span>
                        </div>
                      </Select.Option>
                    ))}
                  </Select>
                </Form.Item>

                <Form.Item
                  name="openingTime"
                  label={<span className="font-semibold dark:text-white">Giờ mở cửa</span>}
                  rules={[{ required: true, message: 'Chọn giờ mở cửa!' }]}
                >
                  <TimePicker format="HH:mm" minuteStep={30} className="w-full rounded-md" allowClear={false} />
                </Form.Item>

                <Form.Item
                  name="closingTime"
                  label={<span className="font-semibold dark:text-white">Giờ đóng cửa</span>}
                  rules={[{ required: true, message: 'Chọn giờ đóng cửa!' }]}
                >
                  <TimePicker format="HH:mm" minuteStep={30} className="w-full rounded-md" allowClear={false} />
                </Form.Item>

                <Form.Item
                  name="slotDuration"
                  label={<span className="font-semibold dark:text-white">Độ dài 1 ca đấu</span>}
                  rules={[{ required: true }]}
                >
                  <Select className="rounded-md">
                    <Select.Option value={30}>30 phút</Select.Option>
                    <Select.Option value={45}>45 phút</Select.Option>
                    <Select.Option value={60}>60 phút (1 tiếng)</Select.Option>
                    <Select.Option value={90}>90 phút (1h30)</Select.Option>
                    <Select.Option value={120}>120 phút (2 tiếng)</Select.Option>
                  </Select>
                </Form.Item>

                <Divider className="my-4 border-semantic-border/10 dark:border-semantic-borderDark/10" />

                <Button
                  type="primary"
                  icon={<SaveOutlined />}
                  onClick={handleSaveConfig}
                  disabled={!!validationError || previewSlots.length === 0}
                  loading={saving}
                  block
                  size="large"
                  className="bg-brand-orange hover:bg-brand-orange/90 border-none font-semibold rounded-md shadow-md"
                >
                  Lưu cấu hình sân
                </Button>
              </Form>
            </Card>
          </Col>

          {/* Right panel: dynamic preview board */}
          <Col xs={24} md={16}>
            <Card 
              title={<span className="font-semibold dark:text-white">Xem trước & Thiết lập trạng thái ca đấu</span>}
              className="rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 bg-white dark:bg-surface-dark1 shadow-sm min-h-[400px]"
            >
              {validationError ? (
                <Alert
                  message="Lỗi cấu hình thời gian"
                  description={validationError}
                  type="error"
                  showIcon
                  className="rounded-md"
                />
              ) : previewSlots.length === 0 ? (
                <div className="text-center py-12 text-ink-muted dark:text-ink-darkMuted">
                  Vui lòng điền thông tin giờ mở/đóng cửa hợp lệ để xem trước sơ đồ.
                </div>
              ) : (
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <Text className="text-ink-muted dark:text-ink-darkMuted text-xs">
                      * Nhấp vào ô thời gian bên dưới để bật/tắt hoạt động của ca đấu.
                    </Text>
                    <Space size="middle">
                      <span className="flex items-center gap-1.5 text-xs">
                        <span className="w-3.5 h-3.5 rounded-sm bg-emerald-500" />
                        <span className="dark:text-white">Khả dụng</span>
                      </span>
                      <span className="flex items-center gap-1.5 text-xs">
                        <span className="w-3.5 h-3.5 rounded-sm bg-red-500" />
                        <span className="dark:text-white">Bảo trì/Tắt</span>
                      </span>
                    </Space>
                  </div>

                  <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
                    {previewSlots.map((slot) => (
                      <div
                        key={slot.slotIndex}
                        onClick={() => handleToggleSlot(slot.slotIndex)}
                        className={`p-3 rounded-lg border flex flex-col justify-between h-20 transition-all cursor-pointer shadow-sm hover:scale-[1.02] ${
                          slot.isAvailable
                            ? 'border-emerald-200 bg-emerald-50 dark:bg-emerald-950/20 text-emerald-700 hover:border-emerald-400'
                            : 'border-red-200 bg-red-50 dark:bg-red-950/20 text-red-700 hover:border-red-400'
                        }`}
                      >
                        <div className="flex items-center justify-between">
                          <span className="font-bold text-xs">Ca {slot.slotIndex}</span>
                          {slot.isAvailable ? (
                            <CheckCircleOutlined className="text-emerald-500 text-xs" />
                          ) : (
                            <CloseCircleOutlined className="text-red-500 text-xs" />
                          )}
                        </div>
                        <span className="text-xs font-semibold block mt-2 text-ink dark:text-white">
                          {minutesToTimeStr(slot.startMinutes)} - {minutesToTimeStr(slot.endMinutes)}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </Card>
          </Col>
        </Row>
      )}
    </div>
  );
};

export default StaffSlotsPage;
