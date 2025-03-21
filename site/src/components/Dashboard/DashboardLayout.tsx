import { useMachine } from "@xstate/react";
import { DeploymentBanner } from "./DeploymentBanner/DeploymentBanner";
import { LicenseBanner } from "components/Dashboard/LicenseBanner/LicenseBanner";
import { Loader } from "components/Loader/Loader";
import { ServiceBanner } from "components/Dashboard/ServiceBanner/ServiceBanner";
import { usePermissions } from "hooks/usePermissions";
import { FC, Suspense } from "react";
import { Outlet } from "react-router-dom";
import { dashboardContentBottomPadding } from "theme/constants";
import { updateCheckMachine } from "xServices/updateCheck/updateCheckXService";
import { Navbar } from "./Navbar/Navbar";
import Snackbar from "@mui/material/Snackbar";
import Link from "@mui/material/Link";
import Box, { BoxProps } from "@mui/material/Box";
import InfoOutlined from "@mui/icons-material/InfoOutlined";
import Button from "@mui/material/Button";
import { docs } from "utils/docs";

export const DashboardLayout: FC = () => {
  const permissions = usePermissions();
  const [updateCheckState, updateCheckSend] = useMachine(updateCheckMachine, {
    context: {
      permissions,
    },
  });
  const { updateCheck } = updateCheckState.context;
  const canViewDeployment = Boolean(permissions.viewDeploymentValues);

  return (
    <>
      <ServiceBanner />
      {canViewDeployment && <LicenseBanner />}

      <div
        css={{
          display: "flex",
          minHeight: "100%",
          flexDirection: "column",
        }}
      >
        <Navbar />

        <div
          css={{
            flex: 1,
            paddingBottom: dashboardContentBottomPadding, // Add bottom space since we don't use a footer
            display: "flex",
            flexDirection: "column",
          }}
        >
          <Suspense fallback={<Loader />}>
            <Outlet />
          </Suspense>
        </div>

        <DeploymentBanner />

        <Snackbar
          data-testid="update-check-snackbar"
          open={updateCheckState.matches("show")}
          anchorOrigin={{
            vertical: "bottom",
            horizontal: "right",
          }}
          ContentProps={{
            sx: (theme) => ({
              background: theme.palette.background.paper,
              color: theme.palette.text.primary,
              maxWidth: theme.spacing(55),
              flexDirection: "row",
              borderColor: theme.palette.info.light,

              "& .MuiSnackbarContent-message": {
                flex: 1,
              },

              "& .MuiSnackbarContent-action": {
                marginRight: 0,
              },
            }),
          }}
          message={
            <Box display="flex" gap={2}>
              <InfoOutlined
                sx={(theme) => ({
                  fontSize: 16,
                  height: 20, // 20 is the height of the text line so we can align them
                  color: theme.palette.info.light,
                })}
              />
              <Box>
                Coder {updateCheck?.version} is now available. View the{" "}
                <Link href={updateCheck?.url}>release notes</Link> and{" "}
                <Link href={docs("/admin/upgrade")}>upgrade instructions</Link>{" "}
                for more information.
              </Box>
            </Box>
          }
          action={
            <Button
              variant="text"
              size="small"
              onClick={() => updateCheckSend("DISMISS")}
            >
              Dismiss
            </Button>
          }
        />
      </div>
    </>
  );
};

export const DashboardFullPage = (props: BoxProps) => {
  return (
    <Box
      {...props}
      sx={{
        ...props.sx,
        marginBottom: `-${dashboardContentBottomPadding}px`,
        flex: 1,
        display: "flex",
        flexDirection: "column",
        flexBasis: 0,
        minHeight: "100%",
      }}
    />
  );
};
